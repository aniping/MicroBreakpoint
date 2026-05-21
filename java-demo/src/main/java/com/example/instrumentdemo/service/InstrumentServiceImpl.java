package com.example.instrumentdemo.service;

import com.example.instrumentdemo.annotation.Description;
import com.example.instrumentdemo.annotation.EntryDefine;
import com.example.instrumentdemo.annotation.ParameterDefine;
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
            @ParameterDefine("仪表编号") @Description("仪表编号") String indexId,
            @ParameterDefine("参数") @Description("扩展参数") Map<String, Object> params) {
        sleep(300);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("instType", instType);
        data.put("indexId", indexId);
        data.put("initialized", true);
        data.put("params", params);
        return ValueResult.success("initialize success", data);
    }

    @Override
    @EntryDefine("仪表控制")
    @Description("通过槽位号转换 hid 号，操作对应仪器仪表实例")
    public ValueResult instrumentControl(
            @ParameterDefine("仪表类型") @Description("仪表类型") String instType,
            @ParameterDefine("仪表操作") @Description("仪表操作") String cmdName,
            @ParameterDefine("槽位id") @Description("槽位id") int slotId,
            @ParameterDefine("参数") @Description("扩展参数") Map<String, Object> params) {
        sleep(500);
        if ("error".equalsIgnoreCase(cmdName)) {
            throw new RuntimeException("simulated instrument control error");
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("instType", instType);
        data.put("cmdName", cmdName);
        data.put("slotId", slotId);
        data.put("hid", "hid-" + slotId);
        data.put("params", params);
        return ValueResult.success("control success: " + cmdName, data);
    }

    private void sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
