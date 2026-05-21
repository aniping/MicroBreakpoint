package com.example.instrumentdemo;

import com.example.instrumentdemo.config.DebuggerProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(DebuggerProperties.class)
public class InstrumentDemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(InstrumentDemoApplication.class, args);
    }
}
