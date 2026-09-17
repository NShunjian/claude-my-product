/**
 * 登录页:对齐 uniapp pages/login/index.vue 1:1。
 */
import { router } from '@kit.ArkUI'
import { authStore } from '../stores/auth'
import { getToast } from '../stores/toast'
import { useLanguage } from '../i18n/useLanguage'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'

@Entry
@Component
struct Login {
  @State private username: string = ''
  @State private password: string = ''
  @State private busy: boolean = false
  private lang = useLanguage()

  async login() {
    if (!this.username.trim()) { getToast()?.show(this.lang.t('login.usernameRequired')); return }
    if (!this.password) { getToast()?.show(this.lang.t('login.passwordRequired')); return }
    this.busy = true
    try {
      await authStore.login(this.username.trim(), this.password)
      router.replaceUrl({ url: 'pages/Index' })
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      getToast()?.show(this.lang.t('login.submitErrorPrefix') + msg)
    } finally {
      this.busy = false
    }
  }

  async register() {
    if (!this.username.trim() || !this.password) return
    this.busy = true
    try {
      await authStore.register({ username: this.username.trim(), password: this.password })
      router.replaceUrl({ url: 'pages/Index' })
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      getToast()?.show(this.lang.t('login.submitErrorPrefix') + msg)
    } finally {
      this.busy = false
    }
  }

  build() {
    Column() {
      Row().height(48).width('100%')
      Column() {
        Text('轻账')
          .fontSize(48).fontWeight(FontWeight.Bold)
          .fontColor(resolveTheme(themeStore.effective).colors.primary)
          .margin({ top: 80, bottom: 12 })
        Text(this.lang.t('login.welcome'))
          .fontSize(20).fontWeight(FontWeight.Medium)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
        Text(this.lang.t('login.subtitle'))
          .fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .margin({ top: 4, bottom: 60 })

        Column() {
          Text(this.lang.t('login.username'))
            .fontSize(13)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            .margin({ bottom: 8 })
          TextInput({ text: this.username, placeholder: this.lang.t('login.usernamePlaceholder') })
            .fontSize(15)
            .width('100%').height(48)
            .padding({ left: 16, right: 16 })
            .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
            .borderRadius(8)
            .onChange((v: string) => { this.username = v })

          Text(this.lang.t('login.password'))
            .fontSize(13)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            .margin({ top: 16, bottom: 8 })
          TextInput({ text: this.password, placeholder: this.lang.t('login.passwordPlaceholder') })
            .type(InputType.Password)
            .fontSize(15)
            .width('100%').height(48)
            .padding({ left: 16, right: 16 })
            .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
            .borderRadius(8)
            .onChange((v: string) => { this.password = v })

          Text(this.busy ? '…' : this.lang.t('login.submit'))
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .width('100%').height(48)
            .textAlign(TextAlign.Center)
            .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
            .borderRadius(8)
            .margin({ top: 24 })
            .onClick(() => this.login())

          Row() {
            Text(this.lang.t('login.or'))
              .fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            Text(this.lang.t('login.register'))
              .fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.primary)
              .margin({ left: 4 })
              .onClick(() => this.register())
          }
          .width('100%').justifyContent(FlexAlign.Center).margin({ top: 16 })
        }
        .width('100%').padding(24)
        .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
        .borderRadius(16)
      }
      .layoutWeight(1)
      .padding({ left: 24, right: 24 })
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }
}
