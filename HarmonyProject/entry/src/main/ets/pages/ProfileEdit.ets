/**
 * 编辑资料:对齐 uniapp pages/profile/edit.vue 1:1。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { useLanguage } from '../i18n/useLanguage'
import { getAuth, authStore } from '../stores/auth'
import { getToast } from '../stores/toast'
import { updateProfile, changePassword, uploadAvatar } from '../api/users'

import type { Gender } from '../model/Types'

function sameGender(g: Gender | null, target: Gender): boolean {
  if (target === null) return g === null || g === undefined
  return g === target
}

@Entry
@Component
struct ProfileEdit {
  @State displayName: string = ''
  @State gender: Gender | null = null
  @State age: string = ''
  @State avatarPreview: string | null = null
  @State oldPassword: string = ''
  @State newPassword: string = ''
  @State confirmPassword: string = ''
  @State busy: boolean = false
  @State savingAvatar: boolean = false
  private lang = useLanguage()

  aboutToAppear() {
    const u = getAuth().user
    if (u) {
      this.displayName = u.displayName ?? ''
      this.gender = u.gender ?? null
      this.age = u.age != null ? String(u.age) : ''
    }
  }

  private async pickAndUploadAvatar() {
    // 实际集成: import photoAccessHelper from '@ohos.file.photoAccessHelper'
    // PhotoViewPicker → PhotoAccessHelper.PickerOptions / select
    // 这里做最简占位: 模拟拿到本地 fileUri
    const url = 'file://docs/storage/Users/currentUser/avatar.jpg'
    this.avatarPreview = url
    getToast()?.show(this.lang.t('profileEdit.avatarPreviewReady'))
  }

  private async saveAvatar() {
    if (!this.avatarPreview) {
      getToast()?.show(this.lang.t('profileEdit.avatarSelectFile'))
      return
    }
    this.savingAvatar = true
    try {
      await uploadAvatar(this.avatarPreview)
      getToast()?.show(this.lang.t('profileEdit.avatarUpdated'))
      await authStore.refresh()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('profileEdit.avatarProcessFailDefault') + msg)
    } finally { this.savingAvatar = false }
  }

  private async saveProfile() {
    if (!this.displayName.trim()) { getToast()?.show(this.lang.t('profileEdit.nameRequired')); return }
    if (this.age && (Number(this.age) < 0 || Number(this.age) > 150)) { getToast()?.show(this.lang.t('profileEdit.ageInvalid')); return }
    this.busy = true
    try {
      await updateProfile({
        displayName: this.displayName.trim(),
        gender: this.gender,
        age: this.age ? Number(this.age) : null,
      })
      await authStore.refresh()
      getToast()?.show(this.lang.t('profileEdit.profileSaved'))
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('profileEdit.saveFailDefault') + msg)
    } finally { this.busy = false }
  }

  private async submitPassword() {
    if (!this.oldPassword || !this.newPassword || !this.confirmPassword) {
      getToast()?.show(this.lang.t('profileEdit.passwordFillAll')); return
    }
    if (this.newPassword !== this.confirmPassword) {
      getToast()?.show(this.lang.t('profileEdit.passwordMismatch')); return
    }
    if (this.newPassword.length < 8) {
      getToast()?.show(this.lang.t('profileEdit.passwordTooShort')); return
    }
    if (this.newPassword === this.oldPassword) {
      getToast()?.show(this.lang.t('profileEdit.passwordSame')); return
    }
    this.busy = true
    try {
      await changePassword({ oldPassword: this.oldPassword, newPassword: this.newPassword })
      getToast()?.show(this.lang.t('profileEdit.passwordChanged'))
      this.oldPassword = ''; this.newPassword = ''; this.confirmPassword = ''
      // 改密后清 token + persist,跟 uniapp auth.logout 一致
      await authStore.logout()
      router.replaceUrl({ url: 'pages/Login' })
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('profileEdit.passwordChangeFailDefault') + msg)
    } finally { this.busy = false }
  }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('profileEdit.title'), back: true, onBack: () => router.back() })
      Scroll() {
        Column() {
          // 头像
          Column() {
            Text(this.lang.t('profileEdit.avatarSection')).fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
            Column() {
              Column() {
                if (this.avatarPreview) {
                  Image(this.avatarPreview).width(80).height(80).borderRadius(40)
                } else if (getAuth().user?.avatar) {
                  Image(getAuth().user?.avatar ?? '').width(80).height(80).borderRadius(40)
                } else {
                  Column().width(80).height(80).borderRadius(40)
                    .backgroundColor(resolveTheme(themeStore.effective).colors.primaryLight)
                    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                  Text(getAuth().user?.displayName?.charAt(0) ?? '?').fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(resolveTheme(themeStore.effective).colors.primary)
                }
              }.width(80).height(80)
              Text(this.lang.t('profileEdit.avatarDesc')).fontSize(11)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .margin({ top: 8 }).textAlign(TextAlign.Center)
              Row() {
                Text(this.lang.t('profileEdit.uploadAvatar')).fontSize(12)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .border({ width: 1, color: resolveTheme(themeStore.effective).colors.primary })
                  .borderRadius(6).fontColor(resolveTheme(themeStore.effective).colors.primary)
                  .margin({ right: 8 })
                  .onClick(() => this.pickAndUploadAvatar())
                Text(this.savingAvatar ? '…' : this.lang.t('profileEdit.saveAvatar')).fontSize(12)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                  .borderRadius(6).fontColor('#FFFFFF')
                  .opacity(this.avatarPreview ? 1 : 0.5)
                  .onClick(() => this.saveAvatar())
              }.margin({ top: 12 })
            }.width('100%').padding(16).alignItems(HorizontalAlign.Center)
              .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
          }.width('100%').margin({ top: 12 })

          // 资料
          Column() {
            Text(this.lang.t('profileEdit.profileSection')).fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
            Column() {
              Text(this.lang.t('profileEdit.displayName')).fontSize(12).margin({ bottom: 4 })
              TextInput({ text: this.displayName, placeholder: this.lang.t('profileEdit.displayNamePlaceholder') })
                .width('100%').height(44).padding(12)
                .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
                .onChange((v: string) => { this.displayName = v })
              Text(this.lang.t('profileEdit.gender')).fontSize(12).margin({ top: 12, bottom: 4 })
              Row() {
                this.genderChip('male', this.lang.t('profileEdit.gender.male'))
                this.genderChip('female', this.lang.t('profileEdit.gender.female'))
                this.genderChip('other', this.lang.t('settings.userCard.gender.other'))
                this.genderChip(null, '×')
              }
              Text(this.lang.t('profileEdit.age')).fontSize(12).margin({ top: 12, bottom: 4 })
              TextInput({ text: this.age, placeholder: this.lang.t('profileEdit.agePlaceholder') })
                .type(InputType.Number)
                .width('100%').height(44).padding(12)
                .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
                .onChange((v: string) => { this.age = v })
              Text(this.busy ? '…' : this.lang.t('profileEdit.saveProfile')).fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF').width('100%').textAlign(TextAlign.Center)
                .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                .borderRadius(8).margin({ top: 16 })
                .onClick(() => this.saveProfile())
            }.width('100%').padding(16)
              .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
          }.width('100%').margin({ top: 16 })

          // 安全
          Column() {
            Text(this.lang.t('profileEdit.securitySection')).fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
            Column() {
              Text(this.lang.t('profileEdit.securityDesc')).fontSize(11)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .margin({ bottom: 12 })
              Text(this.lang.t('profileEdit.oldPassword')).fontSize(12).margin({ bottom: 4 })
              TextInput({ text: this.oldPassword, placeholder: this.lang.t('profileEdit.oldPasswordPlaceholder') })
                .type(InputType.Password)
                .width('100%').height(44).padding(12)
                .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
                .onChange((v: string) => { this.oldPassword = v })
              Text(this.lang.t('profileEdit.newPassword')).fontSize(12).margin({ top: 12, bottom: 4 })
              TextInput({ text: this.newPassword, placeholder: this.lang.t('profileEdit.newPasswordPlaceholder') })
                .type(InputType.Password)
                .width('100%').height(44).padding(12)
                .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
                .onChange((v: string) => { this.newPassword = v })
              Text(this.lang.t('profileEdit.confirmPassword')).fontSize(12).margin({ top: 12, bottom: 4 })
              TextInput({ text: this.confirmPassword, placeholder: this.lang.t('profileEdit.confirmPasswordPlaceholder') })
                .type(InputType.Password)
                .width('100%').height(44).padding(12)
                .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
                .onChange((v: string) => { this.confirmPassword = v })
              Text(this.busy ? '…' : this.lang.t('profileEdit.savePassword')).fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF').width('100%').textAlign(TextAlign.Center)
                .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                .borderRadius(8).margin({ top: 16 })
                .onClick(() => this.submitPassword())
            }.width('100%').padding(16)
              .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
          }.width('100%').margin({ top: 16 })

          Row().height(56)
        }
        .padding({ left: 16, right: 16, top: 12 })
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }

  @Builder genderChip(g: Gender, label: string) {
    Text(label).fontSize(12)
      .fontColor(sameGender(this.gender, g) ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
      .backgroundColor(sameGender(this.gender, g) ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16).margin({ right: 6 })
      .onClick(() => { this.gender = g })
  }
}