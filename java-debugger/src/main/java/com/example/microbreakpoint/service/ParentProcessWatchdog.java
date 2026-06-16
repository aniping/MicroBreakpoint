package com.example.microbreakpoint.service;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.stereotype.Service;

import com.example.microbreakpoint.config.DebuggerProperties;

@Service
public class ParentProcessWatchdog {

    private final DebuggerProperties properties;
    private final DebugService debugService;
    private final ConfigurableApplicationContext applicationContext;
    private final AtomicBoolean running = new AtomicBoolean(false);
    private Thread thread;

    public ParentProcessWatchdog(
            DebuggerProperties properties,
            DebugService debugService,
            ConfigurableApplicationContext applicationContext) {
        this.properties = properties;
        this.debugService = debugService;
        this.applicationContext = applicationContext;
    }

    @PostConstruct
    public void start() {
        Long parentPid = properties.getParentPid();
        if (parentPid == null || parentPid <= 0) {
            return;
        }
        running.set(true);
        thread = new Thread(() -> watch(parentPid), "micro-breakpoint-parent-watchdog");
        thread.setDaemon(true);
        thread.start();
    }

    @PreDestroy
    public void stop() {
        running.set(false);
        if (thread != null) {
            thread.interrupt();
        }
    }

    private void watch(long parentPid) {
        while (running.get()) {
            if (!isProcessAlive(parentPid)) {
                System.out.println("[MicroBreakpoint] parent process exited, stop Java backend");
                try {
                    debugService.stopDebug();
                } catch (RuntimeException e) {
                    System.out.println("[MicroBreakpoint] stop debug before parent watchdog exit failed: " + e.getMessage());
                }
                running.set(false);
                if (properties.isParentWatchdogExitEnabled()) {
                    int code = SpringApplication.exit(applicationContext, () -> 0);
                    System.exit(code);
                }
                return;
            }
            try {
                Thread.sleep(Math.max(200, properties.getParentCheckIntervalMs()));
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    static boolean isProcessAlive(long pid) {
        if (pid <= 0) {
            return false;
        }
        Optional<ProcessHandle> handle = ProcessHandle.of(pid);
        return handle.map(ProcessHandle::isAlive).orElse(false);
    }
}
