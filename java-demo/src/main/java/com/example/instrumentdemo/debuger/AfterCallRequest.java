package com.example.instrumentdemo.debuger;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class AfterCallRequest {

    private String callId;
    private boolean success;
    private long costMs;
    private Object result;
    private String exceptionType;
    private String exceptionMessage;

}
