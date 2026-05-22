package com.example.instrumentdemo.debuger;

import lombok.Setter;
import lombok.Getter;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Setter
@Getter
public class DebugMethodInfo {

    private String objectName;
    private Integer slotId;
    private String cmdName;
    private String serviceName;
    private String className;
    private String methodName;
    private String displayName;
    private String description;

    private Map<String, Object> args = new LinkedHashMap<>();
    private List<DebugParam> parameterMeta = new ArrayList<>();

    public DebugMethodInfo objectName(String objectName) {
        this.objectName = objectName;
        return this;
    }

    public DebugMethodInfo cmdName(String cmdName) {
        this.cmdName = cmdName;
        return this;
    }

    public DebugMethodInfo slotId(Integer slotId) {
        this.slotId = slotId;
        return this;
    }

    public DebugMethodInfo serviceName(String serviceName) {
        this.serviceName = serviceName;
        return this;
    }

    public DebugMethodInfo className(String className) {
        this.className = className;
        return this;
    }

    public DebugMethodInfo methodName(String methodName) {
        this.methodName = methodName;
        return this;
    }

    public DebugMethodInfo displayName(String displayName) {
        this.displayName = displayName;
        return this;
    }

    public DebugMethodInfo description(String description) {
        this.description = description;
        return this;
    }

    public DebugMethodInfo arg(String name, Object value) {
        this.args.put(name, value);
        return this;
    }

    public DebugMethodInfo param(String name, String displayName, String javaType) {
        this.parameterMeta.add(new DebugParam(name, displayName, javaType));
        return this;
    }

    public static DebugMethodInfo commonMethodData(
            String instType,
            String cmdName,
            String description,
            Integer slotId,
            Map<String, Object> params) {
        return new DebugMethodInfo()
                .objectName(instType)
                .slotId(slotId)
                .cmdName(cmdName)
                .description(description)

                .serviceName("serviceName")
                .className("className")
                .methodName("methodName")

                .arg("params", params)
                .param("params", "操作传参", "java.util.Map");
    }
}
