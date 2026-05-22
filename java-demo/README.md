# Java Demo

Spring Boot 微服务示例，端口 `8080`。Service 方法通过 `DebugInvoker` 包装真实业务调用，并向 Python Debugger 上报 before-call / after-call。

## 启动

```powershell
cd java-demo
mvn spring-boot:run
```

## 接口

- `GET /api/demo/ping`
- `POST /api/demo/initialize`
- `POST /api/demo/control`

`POST /api/demo/control` 请求示例：

```json
{
  "instType": "SA",
  "cmdName": "start",
  "slotId": 1,
  "params": {
    "mode": "AUTO"
  }
}
```

Java 上报中 `objectName`、`cmdName`、`slotId` 和 `params` 都是顶层字段；`rawArgs` 仅作为技术信息保留。

Python Debugger 不在线时，业务接口仍会正常执行；上报失败只会打印警告。
