/**
 * 账本成员:对齐 uniapp pages/books/members.vue 1:1。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { useLanguage } from '../i18n/useLanguage'
import { getAuth } from '../stores/auth'
import { getToast } from '../stores/toast'
import { listMembers, inviteMember, updateMemberRole, removeMember } from '../api/books'
import { consumePendingBookUuid } from '../utils/nav-intent'
import type { BookMember, BookRole } from '../model/Types'

class RoleLabels {
  private store: Map<BookRole, string>
  constructor() {
    this.store = new Map<BookRole, string>()
    this.store.set('owner', '所有者')
    this.store.set('editor', '编辑者')
    this.store.set('viewer', '查看者')
  }
  get(r: BookRole): string { return this.store.get(r) ?? '' }
}
const ROLE_LABELS: RoleLabels = new RoleLabels()

const EDITABLE_ROLES: BookRole[] = ['editor', 'viewer']

@Entry
@Component
struct BookMembers {
  @State members: BookMember[] = []
  @State loading: boolean = false
  @State bookUuid: string = ''
  @State showInvite: boolean = false
  @State inviteUsername: string = ''
  @State inviteRole: BookRole = 'editor'
  private lang = useLanguage()

  aboutToAppear() {
    this.bookUuid = consumePendingBookUuid()
    if (this.bookUuid) this.load()
  }

  async load() {
    this.loading = true
    try { this.members = await listMembers(this.bookUuid) }
    catch (e) { getToast()?.show(e instanceof Error ? (e.message ?? '') : '') }
    finally { this.loading = false }
  }

  async invite() {
    if (!this.inviteUsername.trim()) return
    try {
      await inviteMember(this.bookUuid, this.inviteUsername.trim(), this.inviteRole)
      this.showInvite = false; this.inviteUsername = ''
      getToast()?.show(this.lang.t('members.invite.success'))
      await this.load()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('members.invite.failPrefix') + msg)
    }
  }

  async changeRole(m: BookMember, role: BookRole) {
    try {
      await updateMemberRole(this.bookUuid, m.userId, role)
      getToast()?.show(this.lang.t('members.role.changeSuccess'))
      await this.load()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('members.role.changeFailPrefix') + msg)
    }
  }

  async remove(m: BookMember) {
    try {
      await removeMember(this.bookUuid, m.userId)
      getToast()?.show(this.lang.t('members.remove.success'))
      await this.load()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('members.remove.failPrefix') + msg)
    }
  }

  build() {
    Stack() {
      Column() {
        AppHeader({
          title: this.lang.t('members.heading'),
          back: true, onBack: () => router.back(),
          right: this.inviteHeaderBuilder,
        })
        if (this.loading) {
          Text(this.lang.t('common.loading')).fontSize(13).padding(40).width('100%').textAlign(TextAlign.Center)
        } else if (this.members.length === 0) {
          Text(this.lang.t('members.empty')).fontSize(13).padding(40).width('100%').textAlign(TextAlign.Center)
        } else {
          Column() {
            ForEach(this.members, (m: BookMember) => {
              Row() {
                Column() {
                  Row() {
                    Text(m.displayName || m.username).fontSize(15).fontWeight(FontWeight.Medium)
                    if (m.userId === getAuth().user?.id) {
                      Text(this.lang.t('members.you')).fontSize(11).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                    }
                  }
                  Text(`@${m.username}`).fontSize(11).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                if (m.role !== 'owner') {
                  Row() {
                    ForEach(EDITABLE_ROLES, (r: BookRole) => {
                      Text(ROLE_LABELS.get(r)).fontSize(11)
                        .fontColor(m.role === r ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
                        .backgroundColor(m.role === r ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .borderRadius(12)
                        .margin({ right: 4 })
                        .onClick(() => this.changeRole(m, r))
                    }, (r: BookRole) => r)
                  }.margin({ right: 8 })
                  Text(this.lang.t('members.action.remove')).fontSize(11)
                    .fontColor(resolveTheme(themeStore.effective).colors.error)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .border({ width: 1, color: resolveTheme(themeStore.effective).colors.error })
                    .borderRadius(4)
                    .onClick(() => this.remove(m))
                } else {
                  Text(ROLE_LABELS.get(m.role)).fontSize(11).fontColor(resolveTheme(themeStore.effective).colors.primary)
                    .backgroundColor(resolveTheme(themeStore.effective).colors.primaryLight)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(12)
                }
              }
              .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
            }, (m: BookMember) => m.userId)
          }
          .width('100%').margin({ top: 12 })
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
        }
      }
      .width('100%').height('100%')
      .backgroundColor(resolveTheme(themeStore.effective).colors.bg)

      if (this.showInvite) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor('#00000066')
            .onClick(() => { this.showInvite = false })
          Column() {
            Text(this.lang.t('members.invite')).fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })
            Text(this.lang.t('members.invite.username')).fontSize(12).margin({ bottom: 4 })
            TextInput({ text: this.inviteUsername, placeholder: this.lang.t('members.invite.usernamePlaceholder') })
              .width('100%').height(44).padding(12)
              .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
              .onChange((v: string) => { this.inviteUsername = v })
            Text(this.lang.t('members.invite.role')).fontSize(12).margin({ top: 12, bottom: 4 })
            Row() {
              ForEach(EDITABLE_ROLES, (r: BookRole) => {
                Text(ROLE_LABELS.get(r)).fontSize(12)
                  .fontColor(this.inviteRole === r ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
                  .backgroundColor(this.inviteRole === r ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(16).margin({ right: 8 })
                  .onClick(() => { this.inviteRole = r })
              }, (r: BookRole) => r)
            }
            Row() {
              Text(this.lang.t('common.cancel')).fontSize(14).layoutWeight(1).textAlign(TextAlign.Center)
                .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.surface)
                .borderRadius(8).margin({ right: 8 })
                .onClick(() => { this.showInvite = false })
              Text(this.lang.t('members.invite.submit')).fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF').layoutWeight(1).textAlign(TextAlign.Center)
                .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                .borderRadius(8)
                .onClick(() => this.invite())
            }.width('100%').margin({ top: 16 })
          }
          .width('80%').padding(20)
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)
        }
        .width('100%').height('100%').position({ x: 0, y: 0 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder inviteHeaderBuilder() {
    Text(`+ ${this.lang.t('members.invite')}`).fontSize(13).fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(8)
      .onClick(() => { this.showInvite = true })
  }
}