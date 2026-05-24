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

可以使用脚本批量调用 Java Demo 的全部 REST 接口，并生成几条典型调试流量：

```powershell
cd java-demo
.\scripts\call-all-demo-apis.ps1
```

如果 Java Demo 不在默认端口，可以指定地址：

```powershell
.\scripts\call-all-demo-apis.ps1 -BaseUrl http://127.0.0.1:8080
```

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
