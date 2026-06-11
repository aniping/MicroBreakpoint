package com.example.microbreakpoint.service;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import org.springframework.stereotype.Service;

@Service
public class WaitManager {

    private final ConcurrentHashMap<String, CountDownLatch> waits = new ConcurrentHashMap<>();

    public CountDownLatch create(String callId) {
        return waits.computeIfAbsent(callId, ignored -> new CountDownLatch(1));
    }

    public String waitFor(String callId, long timeoutSeconds) {
        CountDownLatch latch = create(callId);
        boolean released;
        try {
            released = latch.await(timeoutSeconds, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            released = false;
        } finally {
            waits.remove(callId);
        }
        return released ? "continue" : "timeout_continue";
    }

    public boolean continueOne(String callId) {
        CountDownLatch latch = waits.remove(callId);
        if (latch == null) {
            return false;
        }
        latch.countDown();
        return true;
    }

    public int continueAll() {
        List<CountDownLatch> items = new ArrayList<>(waits.values());
        waits.clear();
        items.forEach(CountDownLatch::countDown);
        return items.size();
    }
}
