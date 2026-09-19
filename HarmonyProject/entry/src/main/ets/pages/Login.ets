/**
 * 登录页:对齐 uniapp pages/login/index.vue 1:1。
 */
import { router, promptAction } from '@kit.ArkUI'
import { authStore } from '../stores/auth'
import { getToast } from '../stores/toast'
import { useLanguage } from '../i18n/useLanguage'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { ToastHost } from '../components/Toast'

@Entry
@Component
struct Login {
  @State private username: string = ''
  @State private password: string = ''
  @State private busy: boolean = false
  @State private remember: boolean = true
  private usernameId: string = 'login-username'
  private passwordId: string = 'login-password'
  private lang = useLanguage()

  async login() {
    if (!this.username.trim()) {
      getToast()?.show(this.lang.t('login.usernameRequired'))
      promptAction.showToast({ message: this.lang.t('login.usernameRequired'), duration: 2000 })
      return
    }
    if (!this.password) {
      getToast()?.show(this.lang.t('login.passwordRequired'))
      promptAction.showToast({ message: this.lang.t('login.passwordRequired'), duration: 2000 })
      return
    }
    this.busy = true
    try {
      await authStore.login(this.username.trim(), this.password)
      promptAction.showToast({ message: this.lang.t('login.success'), duration: 1500 })
      router.replaceUrl({ url: 'pages/Index' })
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      const text = this.lang.t('login.submitErrorPrefix') + msg
      getToast()?.show(text)
      promptAction.showToast({ message: text, duration: 3000 })
    } finally {
      this.busy = false
    }
  }

  build() {
    Stack() {
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
              .width('100%').textAlign(TextAlign.Start)
              .margin({ bottom: 8 })
            TextInput({ text: this.username, placeholder: this.lang.t('login.usernamePlaceholder') })
              .id(this.usernameId)
              .fontSize(15)
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
              .borderRadius(8)
              .enabled(!this.busy)
              .enterKeyType(EnterKeyType.Next)
              .onChange((v: string) => { this.username = v })
              .onSubmit(() => {
                focusControl.requestFocus(this.passwordId)
              })

            Text(this.lang.t('login.password'))
              .fontSize(13)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
              .width('100%').textAlign(TextAlign.Start)
              .margin({ top: 16, bottom: 8 })
            TextInput({ text: this.password, placeholder: this.lang.t('login.passwordPlaceholder') })
              .id(this.passwordId)
              .type(InputType.Password)
              .fontSize(15)
              .width('100%').height(48)
              .padding({ left: 16, right: 56 })
              .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
              .borderRadius(8)
              .enabled(!this.busy)
              .enterKeyType(EnterKeyType.Done)
              .onChange((v: string) => { this.password = v })
              .onSubmit(() => { if (!this.busy) this.login() })

            Row() {
              Checkbox({ name: 'remember', group: 'remember' })
                .select(this.remember)
                .width(16).height(16)
                .onChange((v: boolean) => { this.remember = v })
              Text(this.lang.t('login.remember'))
                .fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .margin({ left: 8 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 16 })

            Stack() {
              if (this.busy) {
                Row() {
                  LoadingProgress()
                    .width(20).height(20)
                    .color('#FFFFFF')
                  Text(' ' + this.lang.t('login.submitting'))
                    .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                }
                .width('100%').height(48)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                .borderRadius(8)
              } else {
                Text(this.lang.t('login.submit'))
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  .width('100%').height(48)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                  .borderRadius(8)
                  .onClick(() => this.login())
              }
            }
            .width('100%')
            .margin({ top: 24 })
            .hitTestBehavior(HitTestMode.Default)
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

      ToastHost()
    }
    .width('100%').height('100%')
  }
}
