import { createApp, registerElement } from 'nativescript-vue'
import { InkView } from './canvas/ink-view'
import { InkIcon } from './canvas/icons'
import App from './App.vue'
import './app.css'
registerElement('InkView', () => InkView)
registerElement('InkIcon', () => InkIcon)
createApp(App).start()
