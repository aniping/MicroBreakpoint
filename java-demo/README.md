# Java Demo

Spring Boot 微服务示例，端口 `8080`。Service 方法通过 `DebugInvoker` 包装真实业务调用，并向 Python Debugger 上报 before-call / after-call。

Python Debugger 上报地址在 `src/main/resources/application.yml` 的 `debugger.server-url` 中配置，默认是 `http://127.0.0.1:18601`。

## 启动

```powershell
cd java-demo
mvn spring-boot:run
```

## 接口

- `GET /api/demo/ping`
- `POST /api/demo/initialize`
- `POST /api/demo/control`

可以使用脚本批量调用 Java Demo 的全部 REST 接口，并生成多仪表对象、多样本值、大文本 payload 和多次同接口调用的典型调试流量：

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
