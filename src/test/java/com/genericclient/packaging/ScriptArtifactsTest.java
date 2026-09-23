package com.genericclient.packaging;

import static org.junit.Assert.*;

import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.jar.JarFile;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.Test;
import org.junit.Rule;
import org.junit.rules.TemporaryFolder;

/** Inspect distributed bytes with no access to another script JAR or the source classes. */
public class ScriptArtifactsTest
{
    @Rule public TemporaryFolder temporary = new TemporaryFolder();
    private final Path artifacts = Path.of(System.getProperty("script.artifacts", "build/libs"));
    private final Path sdk = Path.of(System.getProperty("script.sdk"));
    private final Path classes = Path.of(System.getProperty("script.classes", "build/classes/java/main"));

    @Test public void everyCatalogEntryHasExactlyOneJar() throws Exception
    {
        Set<String> expected = new TreeSet<>();
        try (URLClassLoader loader = isolated(classes); Stream<Path> files = Files.walk(classes))
        {
            for (Path file : files.filter(path -> path.toString().endsWith(".class")).collect(Collectors.toList()))
            {
                String name = classes.relativize(file).toString().replace('\\', '/');
                Class<?> type = Class.forName(className(name), false, loader);
                String id = scriptId(type);
                if (id != null) assertTrue("Duplicate source ID " + id, expected.add(id + ".jar"));
            }
        }
        assertFalse("Catalog must not be empty", expected.isEmpty());
        Set<String> actual = jars().stream().map(path -> path.getFileName().toString()).collect(Collectors.toSet());
        assertEquals(expected, actual);
        assertFalse(Files.exists(artifacts.resolve("GenericClientScripts.jar")));
    }

    @Test public void eachJarLoadsAloneAndContainsOneEntryPoint() throws Exception
    {
        for (Path path : jars())
        {
            try (JarFile jar = new JarFile(path.toFile()); URLClassLoader loader = isolated(path))
            {
                List<String> ids = new ArrayList<>();
                for (String name : jar.stream().map(entry -> entry.getName())
                    .filter(name -> name.endsWith(".class")).collect(Collectors.toList()))
                {
                    assertTrue("SDK and packaging code must not ship: " + name,
                        name.startsWith("com/genericclient/scripts/"));
                    Class<?> type = Class.forName(className(name), false, loader);
                    // Resolving members catches absent superclasses and descriptor-only dependencies.
                    type.getDeclaredFields(); type.getDeclaredMethods(); type.getDeclaredConstructors();
                    String id = scriptId(type);
                    if (id != null) ids.add(id);
                }
                assertEquals("One selectable entry per JAR: " + path, 1, ids.size());
                assertEquals(ids.get(0) + ".jar", path.getFileName().toString());
                assertEquals(ids.get(0), jar.getManifest().getMainAttributes().getValue("GenericClient-Script-Id"));
            }
        }
    }

    @Test public void snapeGrassIncludesItsBankResourceButNoOtherScripts() throws Exception
    {
        try (JarFile jar = new JarFile(artifacts.resolve("snape-grass-collector.jar").toFile()))
        {
            String root = "com/genericclient/scripts/";
            assertNotNull(jar.getEntry(root + "gathering/snapegrass/banks.tsv"));
            assertNotNull(jar.getEntry(root + "gathering/snapegrass/SnapeGrassCollector.class"));
            assertFalse(jar.stream().anyMatch(entry -> entry.getName().startsWith(root + "quests/")));
            assertFalse(jar.stream().anyMatch(entry -> entry.getName().startsWith(root + "training/")));
        }
    }

    @Test public void repackagingIsReproducibleAndRemovesStaleCombinedOutput() throws Exception
    {
        Path output = temporary.newFolder().toPath();
        Files.writeString(output.resolve("GenericClientScripts.jar"), "previous combined artifact");
        ScriptPackager.packageScripts(classes, Path.of(System.getProperty("script.resources")), output);
        assertFalse(Files.exists(output.resolve("GenericClientScripts.jar")));
        for (Path jar : jars())
            assertArrayEquals(jar.getFileName().toString(), Files.readAllBytes(jar), Files.readAllBytes(output.resolve(jar.getFileName())));
        assertArrayEquals(Files.readAllBytes(artifacts.resolve("scripts.sha256")), Files.readAllBytes(output.resolve("scripts.sha256")));
    }

    @Test public void bytecodeGraphIncludesDescriptorAndNestedHelperReferences() throws Exception
    {
        Path root = Path.of(ScriptArtifactsTest.class.getProtectionDomain().getCodeSource().getLocation().toURI());
        String fixture = Fixture.class.getName().replace('.', '/');
        String helper = Helper.class.getName().replace('.', '/');
        Set<String> references = ClassDependencies.read(root.resolve(fixture + ".class"), Set.of(fixture, helper));
        assertTrue(references.contains(helper));
    }

    @Test public void invalidBytecodeIsRejected() throws Exception
    {
        Path corrupt = temporary.newFile().toPath();
        Files.writeString(corrupt, "not a class file");
        try { ClassDependencies.read(corrupt, Set.of()); fail("Invalid class must be rejected"); }
        catch (java.io.IOException expected) { assertTrue(expected.getMessage().contains("class file")); }
    }

    static final class Fixture { public List<Helper[]> values; }
    static final class Helper { }

    private List<Path> jars() throws Exception
    {
        try (Stream<Path> files = Files.list(artifacts))
        {
            return files.filter(path -> path.toString().endsWith(".jar")).sorted().collect(Collectors.toList());
        }
    }

    private URLClassLoader isolated(Path path) throws Exception
    {
        return new URLClassLoader(new URL[]{path.toUri().toURL(), sdk.toUri().toURL()}, ClassLoader.getPlatformClassLoader());
    }

    private static String className(String path) { return path.substring(0, path.length() - 6).replace('/', '.'); }

    private static String scriptId(Class<?> type) throws Exception
    {
        boolean script = false;
        String id = null;
        for (java.lang.annotation.Annotation annotation : type.getDeclaredAnnotations())
        {
            String name = annotation.annotationType().getName();
            if (name.equals("org.dreambot.api.script.ScriptManifest")) script = true;
            if (name.equals("com.genericclient.script.ScriptSettings"))
                id = (String) annotation.annotationType().getMethod("id").invoke(annotation);
        }
        return script ? id : null;
    }
}
