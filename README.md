# P31n ZMK 固件

X.Tips P31n 的独立固件仓库。键位迁自 [ZMK-Keyboard 的 `334a632`](https://github.com/xhugoliu/ZMK-Keyboard/commit/334a632752b5630e106b55c85fee9d2239b1a93a)，硬件定义来自 [X.Tips](https://github.com/X-Tips/ZMK-Keyboard/tree/main/p31n)。

- 改键位和并击组合时编辑 [p31n.keymap](boards/shields/p31n/p31n.keymap)。
- 改固件选项时编辑 [p31n.conf](boards/shields/p31n/p31n.conf)。当前支持 USB、蓝牙、鼠标层和 ZMK Studio，按键遥测默认关闭。
- [West 清单](config/west.yml)固定 ZMK、Zephyr 和 P31n 构建所需模块的提交。工作流固定 ZMK 的构建容器，构建时自动拉取依赖。

## 云端构建

在 [Actions → Build P31n firmware](https://github.com/xhugoliu/p31n/actions/workflows/build.yml) 查看产物。

| 固件 | 触发方式 | 下载的文件 |
| --- | --- | --- |
| 公开版 | 推送到 `main`，或点 **Run workflow** 选择 `public` | `p31n-public.uf2` |
| 个人版 | 在 `main` 点 **Run workflow** 并选择 `personal` | `p31n-personal.uf2.age` |

在成功运行的 **Artifacts** 区下载 ZIP 并解压。公开版使用占位宏，可以直接刷机。个人版用 [age](https://github.com/FiloSottile/age) 解密后再刷：

```sh
age -d -i ~/.config/p31n/age-key.txt -o p31n-personal.uf2 p31n-personal.uf2.age
```

可以在任何装有 age 的设备上解密，把 `-i` 改为你的私钥路径即可。

## 换电脑

- 公开版直接从 Actions 下载 ZIP，解压后按下文刷机。如果产物已过期，仓库维护者可以重新运行 `public` 构建。
- 个人版在新电脑安装 [age](https://github.com/FiloSottile/age#installation)，从备份恢复 age 私钥。当前 Mac 的默认路径是 `~/.config/p31n/age-key.txt`。继续使用同一个 GitHub 仓库即可，构建时会读取 `firmware` 环境里已有的宏 Secret。
- 如果丢失私钥，按下文生成新密钥并提交替换后的公钥，再运行一次 `personal`。已有的加密产物仍需要原私钥。

## 配置个人版

初次配置或迁移到自己的仓库时，生成 age 密钥，将公钥写入 `.github/p31n-age-recipients.txt` 并提交。私钥保存在仓库外并自行备份。

```sh
mkdir -p ~/.config/p31n
age-keygen -o ~/.config/p31n/age-key.txt
age-keygen -y ~/.config/p31n/age-key.txt > .github/p31n-age-recipients.txt
```

把原始 `p31n-local-macros.dtsi` 文件编码后存入 `firmware` 环境的 `P31N_LOCAL_MACROS_B64` Secret。该环境的部署分支设为 `main`。

```sh
base64 < /path/to/p31n-local-macros.dtsi | tr -d '\n' |
  gh secret set P31N_LOCAL_MACROS_B64 --env firmware
```

个人构建在 runner 上临时还原宏并加密固件。解密得到的 UF2 含个人宏，请保存在自己的设备上。

## 刷机

1. 用 USB 连接 P31n，按住底排中央 1.5u 键，再按顶排 O 位置进入 bootloader。如果组合键不可用，按 [X.Tips 的说明](https://github.com/X-Tips/ZMK-Keyboard/tree/main/p31n)打开后盖，快速短接 Reset 和 GND 两次。
2. 把 `.uf2` 拖进新出现的 `NICENANO` 磁盘。写入完成后，磁盘会消失，键盘会重启为 `X.P31n Keyboard`。macOS 命令行可用 `cp -X p31n-public.uf2 /Volumes/NICENANO/`，刷个人版时替换文件名。
3. 如果键盘曾通过 ZMK Studio 保存键位，且希望恢复为固件里的键位，在 Studio 中重置键位设置。

有本地 ZMK 工具链时，也可以直接运行 `./scripts/build.sh public`，产物位于 `dist/`。
