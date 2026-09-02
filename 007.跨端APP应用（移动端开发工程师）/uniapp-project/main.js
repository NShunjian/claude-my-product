import App from './App'

// #ifdef H5
// 移动端调试浮窗(dev/prod 都启用,生产打包前手动注释掉这两行)
// Network / Console / Storage / Element 4 个面板,真机扫码调试必备
import VConsole from 'vconsole'
new VConsole()
// #endif

// #ifndef VUE3
import Vue from 'vue'
import './uni.promisify.adaptor'
Vue.config.productionTip = false
App.mpType = 'app'
const app = new Vue({
	...App
})
app.$mount()
// #endif

// #ifdef VUE3
import { createSSRApp } from 'vue'
import * as Pinia from 'pinia'
import './theme/global.scss'
export function createApp() {
	const app = createSSRApp(App)
	app.use(Pinia.createPinia())
	return {
		app
	}
}
// #endif
