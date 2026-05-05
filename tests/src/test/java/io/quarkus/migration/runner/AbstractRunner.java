package io.quarkus.migration.runner;

import java.nio.file.Path;
import java.util.List;

public class AbstractRunner {
    protected String aiCmd;
    protected String provider;
    protected String model;
    protected String strategy;
    protected int timeoutSeconds;
    protected Path skillPath;

    public String prompt;

    public AbstractRunner(String aiCmd, String provider, String model, Path skillPath, String strategy, int timeoutSeconds) {
        this.aiCmd = aiCmd;
        this.provider = provider;
        this.model = model;
        this.skillPath = skillPath;
        this.strategy = strategy;
        this.timeoutSeconds = timeoutSeconds;
        this.prompt = """
            Migrate this Spring Boot project to Quarkus using the %s migration strategy. \
            Work entirely within this directory. \
            Do a full migration — convert all source files, build files, config, and tests. \
            After migration, verify the project compiles with ./mvnw compile and fix any errors. \
            Then run ./mvnw test and fix any test failures.
            If you need to delete code or files, explain why you are deleting them and what you are replacing them with.
            If anything could not be converted/migrated explain why - do not just delete/remove it without explaining.
            Include a summary of the migration in the end of the output.""".formatted(strategy);
    }

    /** Add --provider and/or --model args to the command. Either or both can be set. */
    protected void addModelArgs(List<String> cmd) {
        if (provider != null && !provider.isBlank()) {
            cmd.add("--provider");
            cmd.add(provider);
        }
        if (model != null && !model.isBlank()) {
            cmd.add("--model");
            cmd.add(model);
        }
    }
}
