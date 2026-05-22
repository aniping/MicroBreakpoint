package com.example.instrumentdemo.debuger;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class DebugParam {

    private String name;
    private String displayName;
    private String javaType;

    public DebugParam() {
    }

    public DebugParam(String name, String displayName, String javaType) {
        this.name = name;
        this.displayName = displayName;
        this.javaType = javaType;
    }
}
