package com.example.microbreakpoint.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class ParentProcessWatchdogTest {

    @Test
    void detectsCurrentProcessAndRejectsInvalidPid() {
        long currentPid = ProcessHandle.current().pid();

        assertThat(ParentProcessWatchdog.isProcessAlive(currentPid)).isTrue();
        assertThat(ParentProcessWatchdog.isProcessAlive(-1)).isFalse();
    }
}
