const { resolve } = require('node:path')
const webpack = require('@nativescript/webpack')

module.exports = env => {
  webpack.init(env)
  webpack.Utils.addCopyRule('assets/**')
  webpack.chainWebpack(config => {
    config.resolve.alias.set('vue$', resolve(__dirname, 'node_modules/nativescript-vue'))
  })
  return webpack.resolveConfig()
}
