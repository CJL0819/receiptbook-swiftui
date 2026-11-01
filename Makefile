# ReceiptBook · 本地开发常用命令
# 查看全部命令：make help

.DEFAULT_GOAL := help

PROJECT   := ReceiptBook.xcodeproj
SCHEME    := ReceiptBook
BUNDLE_ID := com.receiptbook
CONFIG    := Debug
OUT       := build

# 两台固定用途的模拟器：
#   EXPERIENCE = 你自己体验的机器（make deploy 会装到这台并启动）
#   VERIFY     = AI 验证用的机器（make verify），不打扰你的会话
EXPERIENCE ?= iPhone 15 Pro
VERIFY     ?= iPhone 15

DEVICE ?= $(EXPERIENCE)

# 按名字精确解析 UDID（找不到返回空）
# 括号交给脚本处理，避免 make 把字面括号当成 $(shell) 的嵌套
udid = $(shell sh scripts/sim-udid.sh "$(1)")

SIM_UDID    := $(call udid,$(DEVICE))
PRO_UDID    := $(call udid,$(EXPERIENCE))
VERIFY_UDID := $(call udid,$(VERIFY))

APP_SIM := $(OUT)/Build/Products/$(CONFIG)-iphonesimulator/ReceiptBook.app
APP_DEV := $(OUT)/device/Build/Products/Release-iphoneos/ReceiptBook.app

.PHONY: help gen project open build run verify deploy reset-data test devices seed ipa clean distclean

help:
	@printf '\n  make gen        生成 %s（改过 project.yml 之后执行）\n' "$(PROJECT)"
	@printf '  make open       生成并用 Xcode 打开工程\n'
	@printf '  make build      编译到模拟器（不安装）\n'
	@printf '  make run        编译 + 装进 %s + 启动\n' "$(DEVICE)"
	@printf '  make verify     编译 + 装进验证机 %s（自动灌示例数据）\n' "$(VERIFY)"
	@printf '  make deploy     编译 + 同时装到体验机与验证机（体验机自动启动）\n'
	@printf '  make reset-data 清空体验机数据并重新灌 8 条示例（仅 Debug）\n'
	@printf '  make test       在验证机上跑 UI 测试（左滑删除 / 撤销）\n'
	@printf '  make seed       用示例数据填充空库（仅 Debug）\n'
	@printf '  make devices    列出可用模拟器\n'
	@printf '  make ipa        本地复现 CI：出未签名 IPA（越狱机用）\n'
	@printf '  make clean      删除 build/ 产物\n'
	@printf '  make distclean  删除 build/ 与生成的 .xcodeproj\n\n'
	@printf '  体验机：%-16s %s\n' "$(EXPERIENCE)" "$(if $(PRO_UDID),$(PRO_UDID),⚠️ 未找到)"
	@printf '  验证机：%-16s %s\n\n' "$(VERIFY)" "$(if $(VERIFY_UDID),$(VERIFY_UDID),⚠️ 未找到)"

gen:
	@command -v xcodegen >/dev/null 2>&1 || { echo "缺少 xcodegen，先执行：brew install xcodegen"; exit 1; }
	xcodegen generate

# 工程不存在时自动生成；已存在则跳过（xcodegen 缺失也能跑已有工程）
project:
	@test -d $(PROJECT) || $(MAKE) --no-print-directory gen

open: project
	open $(PROJECT)

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-destination 'id=$(SIM_UDID)' -derivedDataPath $(OUT) build

# 只编译一次，供多台模拟器复用
sim-build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-sdk iphonesimulator -derivedDataPath $(OUT) build

run: project
	@test -n "$(SIM_UDID)" || { echo "⚠️ 没找到模拟器 $(DEVICE)：先 make devices 查名字"; exit 1; }
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-destination 'id=$(SIM_UDID)' -derivedDataPath $(OUT) build
	@xcrun simctl boot $(SIM_UDID) 2>/dev/null || true
	@open -a Simulator
	@xcrun simctl install $(SIM_UDID) "$(APP_SIM)"
	@xcrun simctl launch $(SIM_UDID) $(BUNDLE_ID)

# AI 验证用：装到 VERIFY 机器，空库时自动灌示例数据
verify: sim-build
	@test -n "$(VERIFY_UDID)" || { echo "⚠️ 没找到验证机 $(VERIFY)：先 make devices"; exit 1; }
	@xcrun simctl boot $(VERIFY_UDID) 2>/dev/null || true
	@xcrun simctl bootstatus $(VERIFY_UDID) -b >/dev/null 2>&1 || true
	@xcrun simctl install $(VERIFY_UDID) "$(APP_SIM)"
	@xcrun simctl terminate $(VERIFY_UDID) $(BUNDLE_ID) 2>/dev/null || true
	@xcrun simctl launch $(VERIFY_UDID) $(BUNDLE_ID) -seedSampleData >/dev/null 2>&1 || true
	@echo "✅ 已部署到验证机 $(VERIFY)（$(VERIFY_UDID)）"

# 交付：同时装到体验机和验证机，体验机直接启动
deploy: sim-build
	@test -n "$(PRO_UDID)" || { echo "⚠️ 没找到体验机 $(EXPERIENCE)：先 make devices"; exit 1; }
	@xcrun simctl boot $(PRO_UDID) 2>/dev/null || true
	@xcrun simctl bootstatus $(PRO_UDID) -b >/dev/null 2>&1 || true
	@xcrun simctl install $(PRO_UDID) "$(APP_SIM)"
	@xcrun simctl terminate $(PRO_UDID) $(BUNDLE_ID) 2>/dev/null || true
	@xcrun simctl launch $(PRO_UDID) $(BUNDLE_ID) >/dev/null 2>&1 || true
	@if [ -n "$(VERIFY_UDID)" ]; then \
		xcrun simctl boot $(VERIFY_UDID) 2>/dev/null || true; \
		xcrun simctl install $(VERIFY_UDID) "$(APP_SIM)"; \
	fi
	@echo "✅ 体验机 $(EXPERIENCE) 已启动；验证机 $(VERIFY) 已同步"

# 只重置体验机的数据（卸载重装 + 灌示例），不动验证机
reset-data: sim-build
	@test -n "$(PRO_UDID)" || { echo "⚠️ 没找到体验机 $(EXPERIENCE)"; exit 1; }
	@xcrun simctl uninstall $(PRO_UDID) $(BUNDLE_ID) 2>/dev/null || true
	@xcrun simctl install $(PRO_UDID) "$(APP_SIM)"
	@xcrun simctl launch $(PRO_UDID) $(BUNDLE_ID) -seedSampleData >/dev/null 2>&1 || true
	@echo "✅ 体验机 $(EXPERIENCE) 数据已重置为 8 条示例"

# UI 测试：在验证机上跑（会先清空 App 数据，保证示例数据能灌进去）
test: project
	@test -n "$(VERIFY_UDID)" || { echo "⚠️ 没找到验证机 $(VERIFY)"; exit 1; }
	@xcrun simctl boot $(VERIFY_UDID) 2>/dev/null || true
	@xcrun simctl uninstall $(VERIFY_UDID) $(BUNDLE_ID) 2>/dev/null || true
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'id=$(VERIFY_UDID)' -derivedDataPath $(OUT)

devices:
	@xcrun simctl list devices available | awk '/^-- iOS/{ print "\n" $$0; next } /iPhone/{ print }'

# 用示例数据填充空库（仅 DEBUG 构建有效；先 make run 或 make verify 装一次）
seed:
	@test -n "$(SIM_UDID)" || { echo "⚠️ 没找到模拟器 $(DEVICE)：先 make devices"; exit 1; }
	@xcrun simctl terminate $(SIM_UDID) $(BUNDLE_ID) 2>/dev/null || true
	@xcrun simctl launch $(SIM_UDID) $(BUNDLE_ID) -seedSampleData

ipa: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk iphoneos -configuration Release \
		-derivedDataPath $(OUT)/device \
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" CODE_SIGN_ENTITLEMENTS="" \
		build
	@rm -rf $(OUT)/ipa && mkdir -p $(OUT)/ipa/Payload
	@cp -R "$(APP_DEV)" $(OUT)/ipa/Payload/
	@cd $(OUT)/ipa && zip -r -q ReceiptBook.ipa Payload && ls -lh ReceiptBook.ipa

clean:
	rm -rf $(OUT)

distclean: clean
	rm -rf $(PROJECT)
