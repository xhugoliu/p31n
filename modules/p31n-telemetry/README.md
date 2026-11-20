# P31n BLE Telemetry

ZMK 外部模块，将 P31n 的 31 个物理位置事件发给 [P31n Insight](https://github.com/xhugoliu/p31n-insight) 或独立 Telemetry Probe。只在当前已配对主机订阅并发送 START 时采集；默认不记录，不写按键到闪存。

默认固件通过 [p31n.conf](../../boards/shields/p31n/p31n.conf) 将 `CONFIG_P31N_TELEMETRY` 设为 `n`。如需恢复采集，将该选项改为 `y` 后重新构建并刷机。

## 行为与协议

监听器链接到 `app`，在 combo/hold-tap 前采集并冒泡原事件。以位置、状态和原始时间戳剔除 combo 重派发；非阻塞队列和独立发送线程避免在按键回调中等待蓝牙发送。队列溢出和发送错误计入状态特征的 dropped。

事件服务 UUID `A0310000-5B5A-4B4D-9A6E-5033314E0001`，事件特征 `A0310001`，控制特征 `A0310002`。20 字节事件包含版本、位置、状态、序号、设备时间、启动标识和采集会话。字段及验收说明在 [p31n-insight 的协议文档](https://github.com/xhugoliu/p31n-insight/blob/main/docs/protocol.md)。

## 去重回归测试

```sh
cc -std=c11 -Wall -Wextra -Werror -I modules/p31n-telemetry \
  modules/p31n-telemetry/tests/replay_filter_test.c -o /tmp/p31n-replay-test
/tmp/p31n-replay-test
```

真机验证覆盖 A 20 次、B＋N 20 次并击、Q 短按/长按、断电重连。续航、长期采集及 Mac 睡眠恢复仍需测量。Studio 仅用于改键或初步链路验证，正式遥测不依赖 Studio。
