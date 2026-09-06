# QingZhang · Flutter 版「轻账」

原 uniapp 跨端记账项目的 1:1 Flutter 翻译,使用 Riverpod + go_router + Dio + fl_chart。

## 目录

- [一、快速跑起来](#一快速跑起来)
- [二、与 uniapp 版本的对应关系](#二与-uniapp-版本的对应关系)
- [三、已知的简化](#三已知的简化)

## 一、快速跑起来

```bash
# 1. 安装依赖
flutter pub get

# 2. 由于本目录不包含 android/ ios/ web/ 等平台目录,先补齐
flutter create --project-name=qingzhang --org=app.qingzhang --platforms=android,ios,web .

# 3. 启动后端(项目后端独立仓库,默认 http://localhost:4001)

# 4. 运行 App
flutter run -d chrome --web-port=5180   # Web/H5,固定 5180 与后端 CORS 白名单对齐
flutter run -d <device-id>              # Android/iOS 设备
```

> `flutter create` 不会修改 `lib/`、`pubspec.yaml` 或 `assets/`。

## 二、与 uniapp 版本的对应关系
z
| uniapp | Flutter |
|---|---|
| pages/login/index.vue | `lib/features/auth/login_screen.dart` |
| pages/index/index.vue | `lib/features/home/home_screen.dart` |
| pages/liushui/index.vue | `lib/features/transactions/transactions_screen.dart` |
| pages/report/index.vue | `lib/features/reports/reports_screen.dart` |
| pages/account/index.vue | `lib/features/accounts/accounts_screen.dart` |
| pages/account/new.vue | `lib/features/accounts/account_new_screen.dart` |
| pages/me/index.vue | `lib/features/settings/settings_screen.dart` |
| pages/record/expense.vue | `lib/features/records/record_expense_screen.dart` |
| pages/record/income.vue | `lib/features/records/record_income_screen.dart` |
| pages/book/index.vue | `lib/features/books/books_screen.dart` |
| pages/book/members.vue | `lib/features/books/book_members_screen.dart` |
| pages/profile/edit.vue | `lib/features/auth/profile_edit_screen.dart` |
| components/AppHeader.vue | `lib/features/shared/app_header.dart` |
| components/Toast.vue | `lib/features/shared/toast.dart` |
| components/MonthPicker.vue | `lib/features/shared/month_picker.dart` |
| components/ColorSwatch.vue | `lib/features/shared/color_swatch.dart` |
| components/TransactionRow.vue | `lib/features/shared/transaction_row.dart` |
| components/RecordForm.vue | `lib/features/records/record_form.dart` |
| components/QuickAddModal.vue | `lib/features/home/quick_add_modal.dart` |
| components/DonutChart.vue | `lib/features/shared/charts/donut_chart.dart` |
| components/charts/LineChart.vue | `lib/features/shared/charts/line_chart.dart` |
| stores/auth.ts | `lib/features/shared/auth_controller.dart` |
| stores/book.ts | `lib/features/shared/book_controller.dart` |
| stores/theme.ts | `lib/features/shared/theme_controller.dart` |
| stores/language.ts | `lib/core/i18n/locale_provider.dart` |
| stores/quick-add.ts | `lib/features/shared/quick_add_controller.dart` |
| utils/* | `lib/core/utils/*` |
| utils/nav-intent.ts | `lib/core/router/nav_intent.dart` |

## 三、已知的简化

- **不跑 `flutter create`**:本仓库只输出 `lib/` + `pubspec.yaml` + 静态资源;用户需手动 `flutter create` 补齐平台目录(README 第一步已说明)。
- **iOS WKWebView 全屏底色**(`uni_modules/qa-window-bg`):Flutter Scaffold 默认填背景色,跳过原生插件。
- **H5 pageshow / popstate 监听 navGrace**:改为在 Dio 拦截器中以 `DateTime.now()` 比较上次 navigation 时间。
- **国际化**:文案用 Dart Map + Riverpod(不走官方 `.arb` + codegen 工具链);但仍引入 `flutter_localizations` SDK 以拿到 `GlobalMaterialLocalizations` 等内置 delegate,保证 `TextField` 等 Material 组件的本地化文案可用。
- **不接 mockito** 等重型库,测试中直接 stub Provider 状态。
- **分享 / 导出**:`share_plus` + `path_provider` 写入临时目录,Web 平台(默认情况下 `kIsWeb`)只显示已保存路径。