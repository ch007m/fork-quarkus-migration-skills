package io.quarkus.migration.runner;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public class OpenCodeRunner extends AbstractRunner implements AgentRunner {

    public OpenCodeRunner(String aiCmd, String provider, String model, Path skillPath, String strategy, int timeoutSeconds) {
        super(aiCmd, provider, model, skillPath, strategy, timeoutSeconds);
    }

    /**
     * Run the migration opencode agent against the given project directory.
     * Streams structured JSON output to console in real-time.
     *
     * @param projectDir the project to migrate
     * @param outputDir  where to store run artifacts (logs, session, etc.)
     * @param runName    prefix for output files (e.g. "spring-rest-api_anthropic_full")
     */
    @Override
    public RunOutput run(Path projectDir, Path outputDir, String runName) throws IOException, InterruptedException {
        Files.createDirectories(outputDir);
        Path sessionDir = Files.createTempDirectory("opencode-session-");

        List<String> cmd = new ArrayList<>();
        cmd.add(aiCmd);
        cmd.add("--no-skills");
        cmd.add("--no-prompt-templates");
        cmd.add("--skill");
        cmd.add(skillPath.toAbsolutePath().toString());
        cmd.add("--session-dir");
        cmd.add(sessionDir.toAbsolutePath().toString());

        addModelArgs(cmd);

        cmd.add(prompt);

        return null;
    }
}
