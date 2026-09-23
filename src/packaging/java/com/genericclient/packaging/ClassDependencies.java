package com.genericclient.packaging;

import java.io.DataInputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Reads symbolic references without loading or initializing script code. */
final class ClassDependencies
{
    private static final Pattern DESCRIPTOR = Pattern.compile("L([\\w$/]+)");
    private static final Set<Integer> FOUR_BYTES = Set.of(3, 4, 9, 10, 11, 12, 17, 18);
    private static final Set<Integer> TWO_BYTES = Set.of(7, 8, 16, 19, 20);

    private ClassDependencies() {}

    static Set<String> read(Path file, Set<String> localClasses) throws IOException
    {
        Set<String> dependencies = new TreeSet<>();
        try (DataInputStream input = new DataInputStream(Files.newInputStream(file)))
        {
            if (input.readInt() != 0xCAFEBABE) throw new IOException("Not a class file: " + file);
            input.readUnsignedShort(); input.readUnsignedShort();
            int count = input.readUnsignedShort();
            for (int index = 1; index < count; index++)
            {
                int tag = input.readUnsignedByte();
                if (tag == 1) collect(input.readUTF(), localClasses, dependencies);
                else if (tag == 5 || tag == 6) { input.readLong(); index++; }
                else if (FOUR_BYTES.contains(tag)) input.readInt();
                else if (TWO_BYTES.contains(tag)) input.readUnsignedShort();
                else if (tag == 15) { input.readUnsignedByte(); input.readUnsignedShort(); }
                else throw new IOException("Unknown constant-pool tag " + tag + " in " + file);
            }
        }
        return dependencies;
    }

    private static void collect(String value, Set<String> localClasses, Set<String> dependencies)
    {
        // Class constants and literal Class.forName names, followed by field/method/generic descriptors.
        String direct = value.replace('.', '/');
        if (localClasses.contains(direct)) dependencies.add(direct);
        Matcher matcher = DESCRIPTOR.matcher(value);
        while (matcher.find())
        {
            String name = matcher.group(1);
            if (localClasses.contains(name)) dependencies.add(name);
        }
    }
}
