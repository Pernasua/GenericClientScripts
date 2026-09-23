package com.genericclient.packaging;

import com.genericclient.script.ScriptSettings;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.lang.reflect.Modifier;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.jar.Attributes;
import java.util.jar.JarEntry;
import java.util.jar.JarOutputStream;
import java.util.jar.Manifest;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.dreambot.api.script.AbstractScript;
import org.dreambot.api.script.ScriptManifest;

/** Build-time only: one entry point and its transitive catalog helpers per distributable. */
public final class ScriptPackager
{
    private ScriptPackager() {}

    public static void main(String[] args) throws Exception
    {
        if (args.length != 3) throw new IllegalArgumentException("Expected classes, resources, output directories");
        packageScripts(Path.of(args[0]), Path.of(args[1]), Path.of(args[2]));
    }

    static void packageScripts(Path classes, Path resources, Path output) throws Exception
    {
        Map<String, Path> files = classFiles(classes);
        Map<String, String> scripts = scripts(classes, files.keySet());
        if (scripts.isEmpty()) throw new IOException("No annotated scripts in " + classes);
        Map<String, Set<String>> graph = new TreeMap<>();
        for (Map.Entry<String, Path> file : files.entrySet())
            graph.put(file.getKey(), ClassDependencies.read(file.getValue(), files.keySet()));

        // Validate all closures before replacing a previous successful distribution.
        Map<String, Set<String>> closures = new TreeMap<>();
        for (Map.Entry<String, String> script : scripts.entrySet())
        {
            Set<String> closure = closure(script.getValue(), graph);
            for (String other : scripts.values())
                if (!other.equals(script.getValue()) && closure.contains(other))
                    throw new IOException(script.getKey() + " depends on another entry point: " + other +
                        "; extract their common logic into a non-script helper");
            closures.put(script.getKey(), closure);
        }

        Files.createDirectories(output.toAbsolutePath().getParent());
        Path staging = Files.createTempDirectory(output.toAbsolutePath().getParent(), "script-jars-");
        try
        {
            List<String> hashes = new ArrayList<>();
            for (Map.Entry<String, String> script : scripts.entrySet())
            {
                Path jar = staging.resolve(script.getKey() + ".jar");
                writeJar(jar, script.getKey(), script.getValue(), closures.get(script.getKey()), files, resources);
                hashes.add(sha256(jar) + "  " + jar.getFileName());
            }
            Files.write(staging.resolve("scripts.sha256"), hashes, StandardCharsets.UTF_8);
            Files.createDirectories(output);
            for (Path file : children(output))
                if (file.getFileName().toString().endsWith(".jar")) Files.delete(file);
            for (Path file : children(staging))
                Files.move(file, output.resolve(file.getFileName()), StandardCopyOption.REPLACE_EXISTING);
            System.out.println("Packaged " + scripts.size() + " standalone script JARs in " + output);
        }
        finally
        {
            for (Path file : children(staging)) Files.deleteIfExists(file);
            Files.deleteIfExists(staging);
        }
    }

    private static Map<String, Path> classFiles(Path root) throws IOException
    {
        Map<String, Path> result = new TreeMap<>();
        try (Stream<Path> files = Files.walk(root))
        {
            for (Path file : files.filter(path -> path.toString().endsWith(".class")).collect(Collectors.toList()))
            {
                String name = root.relativize(file).toString().replace('\\', '/');
                result.put(name.substring(0, name.length() - 6), file);
            }
        }
        return result;
    }

    private static Map<String, String> scripts(Path root, Set<String> names) throws Exception
    {
        Map<String, String> result = new TreeMap<>();
        try (URLClassLoader loader = new URLClassLoader(new URL[]{root.toUri().toURL()}, AbstractScript.class.getClassLoader()))
        {
            for (String name : names)
            {
                Class<?> type = Class.forName(name.replace('/', '.'), false, loader);
                if (type.getDeclaredAnnotation(ScriptManifest.class) == null) continue;
                if (!AbstractScript.class.isAssignableFrom(type) || Modifier.isAbstract(type.getModifiers()))
                    throw new IOException("Annotated entry is not a concrete script: " + name);
                type.getConstructor();
                ScriptSettings settings = type.getDeclaredAnnotation(ScriptSettings.class);
                if (settings == null || !settings.id().matches("[a-z0-9]+(?:-[a-z0-9]+)*"))
                    throw new IOException("Catalog scripts require a safe kebab-case ScriptSettings.id: " + name);
                if (result.putIfAbsent(settings.id(), name) != null)
                    throw new IOException("Duplicate script ID: " + settings.id());
            }
        }
        return result;
    }

    private static Set<String> closure(String entry, Map<String, Set<String>> graph)
    {
        Set<String> result = new TreeSet<>();
        ArrayDeque<String> pending = new ArrayDeque<>(List.of(entry));
        while (!pending.isEmpty())
        {
            String name = pending.remove();
            if (result.add(name)) pending.addAll(graph.get(name));
        }
        return result;
    }

    private static void writeJar(Path path, String id, String entry, Set<String> classes,
        Map<String, Path> files, Path resources) throws IOException
    {
        Map<String, Path> contents = new TreeMap<>();
        Set<String> packages = new TreeSet<>();
        for (String name : classes)
        {
            contents.put(name + ".class", files.get(name));
            packages.add(name.substring(0, name.lastIndexOf('/') + 1));
        }
        if (Files.isDirectory(resources))
        {
            try (Stream<Path> paths = Files.walk(resources))
            {
                for (Path resource : paths.filter(Files::isRegularFile).collect(Collectors.toList()))
                {
                    String name = resources.relativize(resource).toString().replace('\\', '/');
                    if (packages.stream().anyMatch(name::startsWith)) contents.put(name, resource);
                    else if (!name.contains("/")) contents.put(name, resource);
                }
            }
        }
        Manifest manifest = new Manifest();
        Attributes attributes = manifest.getMainAttributes();
        attributes.putValue("Manifest-Version", "1.0");
        attributes.putValue("GenericClient-Script-Id", id);
        attributes.putValue("GenericClient-Script-Class", entry.replace('/', '.'));
        ByteArrayOutputStream metadata = new ByteArrayOutputStream();
        manifest.write(metadata);
        try (JarOutputStream jar = new JarOutputStream(Files.newOutputStream(path)))
        {
            writeEntry(jar, "META-INF/MANIFEST.MF", metadata.toByteArray());
            for (Map.Entry<String, Path> file : contents.entrySet())
                writeEntry(jar, file.getKey(), Files.readAllBytes(file.getValue()));
        }
    }

    private static void writeEntry(JarOutputStream jar, String name, byte[] bytes) throws IOException
    {
        JarEntry entry = new JarEntry(name);
        entry.setTime(0);
        jar.putNextEntry(entry); jar.write(bytes); jar.closeEntry();
    }

    private static String sha256(Path file) throws Exception
    {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(file));
        StringBuilder hex = new StringBuilder();
        for (byte value : digest) hex.append(String.format("%02x", value & 0xff));
        return hex.toString();
    }

    private static List<Path> children(Path directory) throws IOException
    {
        try (Stream<Path> files = Files.list(directory))
        {
            return files.sorted(Comparator.naturalOrder()).collect(Collectors.toList());
        }
    }
}
