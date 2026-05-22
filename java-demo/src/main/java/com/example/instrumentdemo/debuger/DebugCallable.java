package com.example.instrumentdemo.debuger;

@FunctionalInterface
public interface DebugCallable<T> {
    T call() throws Exception;
}
