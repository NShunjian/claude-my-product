/**
 * 我的页(设置):对齐 uniapp pages/settings/index.vue 1:1。
 */
import { router } from '@kit.ArkUI'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { ColorSwatch } from '../components/ColorSwatch'
import { useLanguage, LANGS, LangOption } from '../i18n/useLanguage'
import { getAuth, authStore, appInfo } from '../stores/auth'
import { getToast } from '../stores/toast'
import { themeStore as themeS } from '../stores/theme'
import { languageStore } from '../stores/language'
import { bookStore } from '../stores/book'
import { listCategories, createCategory, updateCategory, deleteCategory } from '../api/categories'
import { exportToCsv } from '../utils/export'
import { getSystemVersion } from '../api/version'
import type { Category } from '../model/Types'

const PALETTE: string[] = ['#005394', '#FF8A65', '#FFB74D', '#9CCC65', '#26A69A', '#7E57C2',
  '#EC407A', '#5C6BC0', '#26C6DA', '#FFCA28', '#66BB6A', '#8D6E63']
const ICONS: string[] = ['🍔','🛒','🚇','🏠','💊','🎮','💼','🎁','📚','✈️','⛽','👕',
  '💰','💵','📈','🎂','🍜','☕','🏋️','🎬','📱','🐶','🏥','🎓']

type CatTab = 'expense' | 'income'

@Entry
@Component
export struct Settings {
  @State catTab: CatTab = 'expense'
  @State cats: Category[] = []
  @State showEdit: boolean = false
  @State editing: Category | null = null
  @State name: string = ''
  @State icon: string = ICONS[0]
  @State color: string = PALETTE[0]
  @State busy: boolean = false
  @State versionText: string = '—'
  @State exporting: boolean = false
  private lang = useLanguage()

  aboutToAppear() {
    this.loadCats()
    this.fetchVersion()
  }

  async loadCats() {
    try { this.cats = await listCategories(this.catTab) }
    catch (e) { getToast()?.show(e instanceof Error ? (e.message ?? '') : '') }
  }

  async fetchVersion() {
    this.versionText = this.lang.t('settings.about.fetchingVersion')
    try {
      const v = await getSystemVersion()
      this.versionText = v ? this.lang.t('settings.about.currentVersion') + ' v' + v.version : this.lang.t('settings.about.versionUnavailable')
    } catch {
      this.versionText = this.lang.t('settings.about.versionUnavailable')
    }
  }

  private switchTab(t: CatTab) {
    this.catTab = t
    this.loadCats()
  }

  private openCreate() {
    this.editing = null
    this.name = ''
    this.icon = ICONS[0]
    this.color = PALETTE[0]
    this.showEdit = true
  }

  private openEdit(c: Category) {
    this.editing = c
    this.name = c.name
    this.icon = c.icon ?? ''
    this.color = c.color
    this.showEdit = true
  }

  private async save() {
    if (!this.name.trim()) return
    this.busy = true
    try {
      if (this.editing) {
        await updateCategory(this.editing.id, { name: this.name.trim(), icon: this.icon, color: this.color })
        getToast()?.show(this.lang.t('settings.categories.edit.success'))
      } else {
        await createCategory({ type: this.catTab, name: this.name.trim(), icon: this.icon, color: this.color })
        getToast()?.show(this.lang.t('settings.categories.create.success'))
      }
      this.showEdit = false
      await this.loadCats()
    } catch (e) {
      const prefix = this.editing ? this.lang.t('settings.categories.edit.failPrefix') : this.lang.t('settings.categories.create.failPrefix')
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(prefix + msg)
    } finally { this.busy = false }
  }

  private async remove(c: Category) {
    try {
      await deleteCategory(c.id)
      getToast()?.show(this.lang.t('settings.categories.delete.success'))
      await this.loadCats()
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('settings.categories.delete.failPrefix') + msg)
    }
  }

  private async exportMonthly(): Promise<void> {
    if (!bookStore.current) return
    this.exporting = true
    try {
      await exportToCsv({ mode: 'monthly', bookId: bookStore.current.uuid })
    } catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('settings.data.exportFailPrefix') + msg)
    }
    finally { this.exporting = false }
  }
  private async exportCategory(): Promise<void> {
    if (!bookStore.current) return
    this.exporting = true
    try { await exportToCsv({ mode: 'category', bookId: bookStore.current.uuid }) }
    catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('settings.data.exportFailPrefix') + msg)
    }
    finally { this.exporting = false }
  }
  private async exportAll(): Promise<void> {
    if (!bookStore.current) return
    this.exporting = true
    try { await exportToCsv({ mode: 'all', bookId: bookStore.current.uuid }) }
    catch (e) {
      const msg = e instanceof Error ? (e.message ?? '') : ''
      getToast()?.show(this.lang.t('settings.data.exportFailPrefix') + msg)
    }
    finally { this.exporting = false }
  }

  private logout() {
    authStore.token = ''
    authStore.user = null
    router.replaceUrl({ url: 'pages/Login' })
  }

  build() {
    Stack() {
      Column() {
        AppHeader({ title: this.lang.t('pageTitle.settings') })

        Scroll() {
          Column() {
            this.userCard()

            this.prefsCard()

            this.categoriesCard()

            this.dataCard()

            this.aboutCard()

            this.accountCard()

            Row().height(56)
          }.padding({ left: 16, right: 16, top: 12 })
        }
        .layoutWeight(1).scrollBar(BarState.Off)
      }
      .width('100%').height('100%')
      .backgroundColor(resolveTheme(themeStore.effective).colors.bg)

      if (this.showEdit) this.editDialog()
    }
    .width('100%').height('100%')
  }

  @Builder userCard() {
    Row() {
      Column() {
        if (this.userAvatar().length > 0) {
          Image(this.userAvatar()).width(56).height(56).borderRadius(28)
        } else {
          Column().width(56).height(56).borderRadius(28)
            .backgroundColor(resolveTheme(themeStore.effective).colors.primaryLight)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          Text(this.userInitial()).fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(resolveTheme(themeStore.effective).colors.primary)
        }
      }.width(56).height(56)
      Column() {
        Text(getAuth().user?.displayName || getAuth().user?.username || '—').fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
        Row() {
          Text(`${this.lang.t('settings.userCard.accountLabel')}: @${getAuth().user?.username ?? '—'}`).fontSize(11)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          Text(' · ').fontSize(11).fontColor(resolveTheme(themeStore.effective).colors.divider)
          Text(this.lang.t('settings.userCard.freeVersion')).fontSize(11)
            .fontColor(resolveTheme(themeStore.effective).colors.primary)
            .backgroundColor(resolveTheme(themeStore.effective).colors.primaryLight)
            .padding({ left: 4, right: 4 }).borderRadius(4)
        }.margin({ top: 2 })
      }.layoutWeight(1).margin({ left: 12 }).alignItems(HorizontalAlign.Start)
      Text(this.lang.t('settings.userCard.editProfile')).fontSize(12)
        .fontColor(resolveTheme(themeStore.effective).colors.primary)
        .onClick(() => router.pushUrl({ url: 'pages/ProfileEdit' }))
    }
    .width('100%').padding(16).margin({ top: 12 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)
  }

  private userInitial(): string {
    const u = getAuth().user
    if (u?.displayName && u.displayName.length > 0) return u.displayName.charAt(0)
    if (u?.username && u.username.length > 0) return u.username.charAt(0)
    return '?'
  }

  private userAvatar(): string { return getAuth().user?.avatar ?? '' }

  @Builder prefsCard() {
    Column() {
      Text(this.lang.t('settings.prefs.title')).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
      Column() {
        Row() {
          Column() {
            Text(this.lang.t('settings.prefs.theme.label')).fontSize(14).fontWeight(FontWeight.Medium)
            Text(this.lang.t('settings.prefs.theme.desc')).fontSize(11)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ top: 2 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Row() {
            this.themeChip('system', this.lang.t('settings.prefs.theme.system'))
            this.themeChip('light', this.lang.t('settings.prefs.theme.light'))
            this.themeChip('dark', this.lang.t('settings.prefs.theme.dark'))
          }
        }.width('100%').padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })

        Row() {
          Column() {
            Text(this.lang.t('settings.prefs.lang.label')).fontSize(14).fontWeight(FontWeight.Medium)
            Text(this.lang.t('settings.prefs.lang.desc')).fontSize(11)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ top: 2 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Row() {
            ForEach(LANGS, (l: LangOption) => {
              Text(l.label).fontSize(11)
                .fontColor(languageStore.lang === l.code ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
                .backgroundColor(languageStore.lang === l.code ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(12).margin({ left: 4 })
                .onClick(() => languageStore.setLang(l.code))
            }, (l: LangOption) => l.code)
          }
        }.width('100%').padding({ top: 12, bottom: 12 })
      }
      .width('100%').padding({ left: 12, right: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
    }.width('100%').margin({ top: 16 })
  }

  @Builder categoriesCard() {
    Column() {
      Text(this.lang.t('settings.categories.title')).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
      Column() {
        Row() {
          Text(this.lang.t('settings.categories.tab.expense')).fontSize(13)
            .fontColor(this.catTab === 'expense' ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
            .backgroundColor(this.catTab === 'expense' ? resolveTheme(themeStore.effective).colors.primary : Color.Transparent)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 }).borderRadius(16)
            .margin({ right: 8 })
            .onClick(() => this.switchTab('expense'))
          Text(this.lang.t('settings.categories.tab.income')).fontSize(13)
            .fontColor(this.catTab === 'income' ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
            .backgroundColor(this.catTab === 'income' ? resolveTheme(themeStore.effective).colors.primary : Color.Transparent)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 }).borderRadius(16)
            .onClick(() => this.switchTab('income'))
          Text(`+ ${this.lang.t('settings.categories.create.toggle')}`).fontSize(11)
            .fontColor(resolveTheme(themeStore.effective).colors.primary)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.primary })
            .borderRadius(4).margin({ left: 8 })
            .onClick(() => this.openCreate())
        }.width('100%').padding({ top: 8, bottom: 8 })

        ForEach(this.cats, (c: Category) => {
          Row() {
            Text(c.icon ?? '').fontSize(20).margin({ right: 8 })
            Column() {
              Text(c.name).fontSize(14).fontWeight(FontWeight.Medium)
              if (c.isPreset) {
                Text(this.lang.t('settings.categories.presetBadge')).fontSize(10)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                  .backgroundColor(resolveTheme(themeStore.effective).colors.divider)
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 }).borderRadius(4)
                  .margin({ top: 2 })
              }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            ColorSwatch({ color: c.color, diameter: 14 })
            if (!c.isPreset) {
              Text(this.lang.t('common.edit')).fontSize(11)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .border({ width: 1, color: resolveTheme(themeStore.effective).colors.primary })
                .borderRadius(4).fontColor(resolveTheme(themeStore.effective).colors.primary)
                .margin({ left: 8 })
                .onClick(() => this.openEdit(c))
              Text(this.lang.t('common.delete')).fontSize(11)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .border({ width: 1, color: resolveTheme(themeStore.effective).colors.error })
                .borderRadius(4).fontColor(resolveTheme(themeStore.effective).colors.error)
                .margin({ left: 4 })
                .onClick(() => this.remove(c))
            }
          }
          .width('100%').padding({ top: 10, bottom: 10 })
          .border({ width: { top: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
        }, (c: Category) => c.id)
      }
      .width('100%').padding({ left: 12, right: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
    }.width('100%').margin({ top: 16 })
  }

  @Builder dataCard() {
    Column() {
      Text(this.lang.t('settings.data.title')).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
      Column() {
        Text(this.lang.t('settings.data.exportDesc')).fontSize(11)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .margin({ bottom: 8 })
        this.exportRow(this.lang.t('settings.data.exportMonthly'), () => this.exportMonthly())
        this.exportRow(this.lang.t('settings.data.exportCategory'), () => this.exportCategory())
        this.exportRow(this.lang.t('settings.data.exportAll'), () => this.exportAll())
      }
      .width('100%').padding({ left: 12, right: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
    }.width('100%').margin({ top: 16 })
  }

  @Builder aboutCard() {
    Column() {
      Text(this.lang.t('settings.about.title')).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
      Column() {
        Row() {
          Text(`v${appInfo.version}`).fontSize(13).layoutWeight(1)
          Text(this.versionText).fontSize(11)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        }.width('100%').padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
        Row() {
          Text(this.lang.t('settings.about.terms')).fontSize(14).layoutWeight(1).padding({ top: 12, bottom: 12 })
            .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
        }
        Row() {
          Text(this.lang.t('settings.about.privacy')).fontSize(14).layoutWeight(1).padding({ top: 12, bottom: 12 })
        }
      }
      .width('100%').padding({ left: 12, right: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
    }.width('100%').margin({ top: 16 })
  }

  @Builder accountCard() {
    Column() {
      Text(this.lang.t('settings.accountSecurity.title')).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ bottom: 8 })
      Column() {
        Text(this.lang.t('settings.accountSecurity.desc')).fontSize(11)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .margin({ bottom: 8 })
        Text(this.lang.t('settings.accountSecurity.logout')).fontSize(14)
          .fontColor(resolveTheme(themeStore.effective).colors.error)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => this.logout())
      }
      .width('100%').padding({ left: 12, right: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(12)
    }.width('100%').margin({ top: 16 })
  }

  @Builder themeChip(t: 'system' | 'light' | 'dark', label: string) {
    Text(label).fontSize(11)
      .fontColor(themeS.mode === t ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
      .backgroundColor(themeS.mode === t ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(12).margin({ left: 4 })
      .onClick(() => themeS.setMode(t))
  }

  @Builder exportRow(label: string, onTap: () => void) {
    Row() {
      Text(label).fontSize(14).layoutWeight(1)
      Text(this.exporting ? this.lang.t('settings.data.exporting') : 'CSV →').fontSize(11)
        .fontColor(resolveTheme(themeStore.effective).colors.primary)
    }.width('100%').padding({ top: 12, bottom: 12 })
      .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
      .onClick(() => onTap())
  }

  @Builder editDialog() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#00000088')
        .onClick(() => { this.showEdit = false })
      Column() {
        Text(this.editing ? this.lang.t('settings.categories.edit.title') : this.lang.t('settings.categories.create.title'))
          .fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })
        Text(this.lang.t('settings.categories.field.name')).fontSize(12).margin({ bottom: 4 })
        TextInput({ text: this.name, placeholder: '' })
          .width('100%').height(44).padding(12)
          .backgroundColor(resolveTheme(themeStore.effective).colors.surface).borderRadius(8)
          .onChange((v: string) => { this.name = v })
        Text(this.lang.t('settings.categories.field.icon')).fontSize(12).margin({ top: 12, bottom: 4 })
        Scroll() {
          Row() {
            ForEach(ICONS, (ic: string) => {
              Column() {
                Text(ic).fontSize(20)
                  .fontColor(this.icon === ic ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.textVariant)
              }
              .width(44).height(44).borderRadius(8)
              .backgroundColor(this.icon === ic ? resolveTheme(themeStore.effective).colors.primaryLight : Color.Transparent)
              .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .border({ width: 1, color: this.icon === ic ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.divider })
              .margin({ right: 4 })
              .onClick(() => { this.icon = ic })
            }, (ic: string) => ic)
          }
        }
        .scrollable(ScrollDirection.Horizontal).width('100%')
        Text(this.lang.t('settings.categories.field.color')).fontSize(12).margin({ top: 12, bottom: 4 })
        Row() {
          ForEach(PALETTE, (co: string) => {
            ColorSwatch({ color: co, selected: this.color === co, diameter: 28 })
              .margin({ right: 6 }).onClick(() => { this.color = co })
          }, (co: string) => co)
        }
        Row() {
          Text(this.lang.t('common.cancel')).fontSize(14).layoutWeight(1).textAlign(TextAlign.Center)
            .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.surface)
            .borderRadius(8).margin({ right: 8 })
            .onClick(() => { this.showEdit = false })
          Text(this.busy ? '…' : this.lang.t('common.save')).fontSize(14).fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF').layoutWeight(1).textAlign(TextAlign.Center)
            .padding(12).backgroundColor(resolveTheme(themeStore.effective).colors.primary)
            .borderRadius(8).opacity(this.name.trim() ? 1 : 0.5)
            .onClick(() => this.save())
        }.width('100%').margin({ top: 16 })
      }
      .width('85%').padding(20)
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)
    }
    .width('100%').height('100%').position({ x: 0, y: 0 })
  }
}
