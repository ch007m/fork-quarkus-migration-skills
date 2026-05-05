package io.quarkus.migration.runner;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;

public class AbstractRunner {
    protected String aiCmd;
    protected String provider;
    protected String model;
    protected String strategy;
    protected int timeoutSeconds;
    protected Path skillPath;
    protected String prompt;

    public AbstractRunner(String aiCmd, String provider, String model, Path skillPath, String strategy, int timeoutSeconds, String prompt) {
        this.aiCmd = aiCmd;
        this.provider = provider;
        this.model = model;
        this.skillPath = skillPath;
        this.strategy = strategy;
        this.timeoutSeconds = timeoutSeconds;
        this.prompt = prompt;
    }

    /**
     * Add the model args to the command.
     * @param cmd The Ai command to be enriched with the provider/model
     */
    protected void addModelArgs(List<String> cmd) {
        boolean hasProvider = provider != null && !provider.isBlank();
        boolean hasModel = model != null && !model.isBlank();

        if (hasProvider && hasModel) {
            cmd.add("-m");
            cmd.add(provider + "/" + model);
        } else if (hasModel) {
            cmd.add("-m");
            cmd.add(model);
        }
    }

    public void copySkills(Path source, Path target) throws IOException {
        // Use try-with-resources to auto-close the stream
        try (var stream = Files.walk(source)) {
            stream.forEach(sourcePath -> {
                try {
                    // Resolve target path relative to source
                    Path targetPath = target.resolve(source.relativize(sourcePath));

                    if (Files.isDirectory(sourcePath)) {
                        // Create directories (including parents)
                        Files.createDirectories(targetPath);
                    } else {
                        // Copy file with attributes and overwrite existing
                        Files.copy(sourcePath, targetPath,
                                StandardCopyOption.REPLACE_EXISTING,
                                StandardCopyOption.COPY_ATTRIBUTES);
                    }
                } catch (IOException e) {
                    throw new RuntimeException(e); // Handle or propagate
                }
            });
        }
    }

    public String generateMigrationPrompt() {
        return """
               Migrate this Spring Boot project to Quarkus using the %s migration strategy. \\
               Work entirely within this directory. \\
               Do a full migration — convert all source files, build files, config, and tests. \\
               After migration, verify the project compiles with ./mvnw compile and fix any errors. \\
               Then run ./mvnw test and fix any test failures.
               If you need to delete code or files, explain why you are deleting them and what you are replacing them with.
               If anything could not be converted/migrated explain why - do not just delete/remove it without explaining.
               Include a summary of the migration in the end of the output.""".formatted(strategy);
    }
}
