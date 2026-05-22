package com.example.instrumentdemo.service;

import com.example.instrumentdemo.annotation.Description;
import com.example.instrumentdemo.annotation.EntryDefine;
import com.example.instrumentdemo.annotation.ParameterDefine;
import com.example.instrumentdemo.debuger.DebugInvoker;
import com.example.instrumentdemo.debuger.DebugMethodInfo;
import com.example.instrumentdemo.model.ValueResult;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.stereotype.Service;

@Service
public class InstrumentServiceImpl implements InstrumentService {
    @Override
    @EntryDefine("仪表初始化")
    @Description("初始化指定类型和编号的仪表")
    public ValueResult instrumentInitialize(
            @ParameterDefine("仪表类型") @Description("仪表类型") String instType,
            @ParameterDefine("仪表编号") @Description("仪表编号") int slotId,
            @ParameterDefine("参数") @Description("扩展参数") Map<String, Object> params) {
        return DebugInvoker.invoke(
                DebugMethodInfo.commonMethodData(
                        instType, "INIT", "instrumentInitialize", slotId, params),
                () -> {
                    // 这里先放原来的真实业务逻辑
                    sleep(300);
                    return ValueResult.success(String.format("%s%d: INIT success.", instType, slotId), params);
                }
        );
    }

    @Override
    @EntryDefine("仪表控制")
    @Description("通过槽位号转换 hid 号，操作对应仪器仪表实例")
    public ValueResult instrumentControl(
            @ParameterDefine("仪表类型") @Description("仪表类型") String instType,
            @ParameterDefine("仪表操作") @Description("仪表操作") String cmdName,
            @ParameterDefine("槽位id") @Description("槽位id") int slotId,
            @ParameterDefine("参数") @Description("扩展参数") Map<String, Object> params) {
        return DebugInvoker.invoke(
                DebugMethodInfo.commonMethodData(instType, cmdName, "instrumentControl", slotId, params),
                () -> {
                    // 这里先放原来的真实业务逻辑
                    sleep(500);
                    if ("error".equalsIgnoreCase(cmdName)) {
                        throw new RuntimeException("simulated instrument control error");
                    }
                    return ValueResult.success(String.format("%s%d: %s success.", instType, slotId, cmdName), params);
                }
        );
    }

    private void sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
