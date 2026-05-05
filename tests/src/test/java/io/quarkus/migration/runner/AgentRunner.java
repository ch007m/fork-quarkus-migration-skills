package io.quarkus.migration.runner;

import java.io.IOException;
import java.nio.file.Path;
import java.time.Duration;

public interface AgentRunner {
    RunOutput run(Path projectDir, Path outputDir, String runName) throws IOException, InterruptedException;

    record RunOutput(int exitCode, Duration duration, String sessionFile, String logFile) {}
    record UsageStats(long totalTokens, double totalCost, int apiCalls, String actualModel) {}
    record ReviewOutput(String review, UsageStats usage) {}
}
