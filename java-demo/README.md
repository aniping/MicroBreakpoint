# Java Demo

Spring Boot 微服务示例，端口 `8080`，Service 方法通过 `@EntryDefine` 被 AOP 拦截并向 Python Debugger 上报。

## 启动

```powershell
cd java-demo
mvn spring-boot:run
```

## 接口

- `GET /api/demo/ping`
- `GET /api/demo/initialize`
- `GET /api/demo/control?instType=VNA&cmdName=create&slotId=1`
- `GET /api/demo/error`

Python Debugger 不在线时，业务接口仍会正常执行；上报失败只会打印警告。
