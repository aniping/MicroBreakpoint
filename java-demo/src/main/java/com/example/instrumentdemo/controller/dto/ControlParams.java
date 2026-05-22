package com.example.instrumentdemo.controller.dto;

import lombok.Data;

import java.util.Map;

@Data
public class ControlParams {
    String instType;
    String cmdName;
    int slotId;
    Map<String, Object> params;
}
