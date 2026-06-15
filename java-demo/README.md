# Java Demo

Spring Boot 微服务示例，端口 `8080`。Service 方法通过 `DebugInvoker` 包装真实业务调用，并向 Python Debugger 上报 before-call / after-call。

Python Debugger 上报地址在 `src/main/resources/application.yml` 的 `debugger.server-url` 中配置，默认是 `http://127.0.0.1:18601`。

Java Demo 默认以 `debugger.enabled=false` 启动。断点程序点击“开始调试”后，会请求 Demo 的 `/api/demo/debugger/enabled` 打开上报开关；点击“停止调试”后会请求同一接口关闭开关。

## 启动

```powershell
cd java-demo
mvn spring-boot:run
```

## 接口

- `GET /api/demo/ping`
- `POST /api/demo/debugger/enabled`
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

Python Debugger 不在线时，业务接口仍会正常执行；上报失败会打印警告，并自动把本地 `debugger.enabled` 关闭，避免断点程序异常退出后持续发起失败请求。
