# この章の目標

- [ ] StackNavigatorを使いこなせるようになる
- [ ] StackActionに使って変則的な画面遷移も出来るようになる

# 画面遷移の実装

## ReactNavigation
フルスクラッチでの画面遷移実装は大変なので[ReactNavigation](https://github.com/react-navigation/react-navigation)を利用します。

## セットアップ
```sh
yarn add react-navigation
yarn add @types/react-navigation -D
yarn start
```

# 提供されているNavigator

ReactNavigationはiOSやAndroidでよく使われるいくつかの画面切り替えのためのUIコンポーネントを提供しています。今回はStackNavigatorを利用します。

- StackNavigator
- SwitchNavigator
- DrawerNavigator
- TabNavigator
- BottomTabNavigator
- MaterialBottomTabNavigator
- MaterialTopTabNavigator

他のNavigatorの動作を見たい場合はExpoにショーケースアプリが配信されているので利用すると便利です。
https://expo.io/@react-navigation/NavigationPlayground


## StackNavigatorについて

StackNavigationは基本となるもので、画面切り替えと遷移スタックの管理を提供します。何も設定しなくてもヘッダーなどはそれっぽい見た目に合わせてくれます。

## 実装例

"Hello world!"を表示するだけのアプリがあると仮定して、これをStackNavigator経由で起動します。

### Before

```typescript
//App.tsx ここがルートコンポーネントとする
export default class App extends React.Component<{}, {}> {
  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.text}>Hello world!!</Text>
      </View>
    );
  }
}
```

### After


```typescript
// App.tsx
import { createStackNavigator } from 'react-navigation';
import HomeScreen from './HomeScreen';

// ルートコンポーネントをStackNavigatorに切り替える
export default createStackNavigator({
  [HomeScreen.routeName]: { screen: HomeScreen }
});
```

各画面に1:1対応する`routeName`というstatic stringを定義します。

```typescript
// HomeScreen.tsx
export default class HomeScreen extends React.Component<{}, {}> {
  static routeName = '/HomeScreen';
  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.text}>Hello world!!</Text>
      </View>
    );
  }
}
```


# 画面遷移

ReactNavigationを経由してマウントされたコンポーネントの`Props`に`navigation`が入っています。これを利用して他画面への遷移操作ができます。

## 基本の画面遷移:navigate

`createStackNavigator`に登録したスクリーンであれば`navigation.navigate(routeName: "hoge")`で遷移することができます。

```typescript
import {  NavigationScreenProp,  NavigationRoute } from 'react-navigation';
type Navigation = NavigationScreenProp<NavigationRoute<any>, any>;

interface Props{
  navigation: Navigation;
}

//....

private handleHomeScreen = () => {
  const navigation = this.props.navigation
  const params = {userName: "ReactNative太郎"} // 遷移先の画面に値が渡す
  navigation.navigate({ routeName: HomeScreen.routeName, params });
}

```
## 複雑な画面遷移: dispatch+stackAction

例えば `アプリを起動->ログイン画面->(ログイン成功)->ホーム画面` という画面遷移があった場合、ホーム画面でエッジスワイプや戻るボタン押された際はアプリは終了するべきだと思われます。しかし`navigate`を使ってログイン画面からホーム画面に遷移してしまうと戻ることが出来てしまいます。  
このような特殊なケースは`StackAction`を使って詳細な制御する方法があるので紹介します。下記には画面遷移はするがスタックに積まない場合の`StackAction`の設定を載せました。

https://reactnavigation.org/docs/en/stack-actions.html

```typescript
const resetAction = StackActions.reset({
  index: 0,
  actions: [NavigationActions.navigate({ routeName: HomeScreen.routeName })],
});
this.props.navigation.dispatch(resetAction);
```


# [課題5-1] ログイン画面からホーム画面への遷移(10min)

- `StackNavigator`を利用して先程作ったログインボタンを押すと新しく作ったホーム画面に遷移する機能を実装してください。
- AndroidのバックボタンやiOSのエッジスワイプをした時にログイン画面に戻らずアプリが終了するようにしてください。

### スクリーンショット

| iOS | Android |
| :----: | :------: |
| <img src="images/05-01.gif" width=400 /> | <img src="images/05-02.gif" width=400 /> |

# KeyboardAvoidingViewが上手く機能しない場合

ReactNavigationとKeyboardAvoidingViewは非常に相性が悪く、Navigatorコンポーネント以下にKeyboardAvoidingViewがあると上手く動作しない事が多いです。
ワークアラウンドですがKeyboardAvoidingViewの内部にNavigatorを配置するView構造にすると解決します。

```tsx
const StackNavigator = createStackNavigator({
  [LoginScreen.routeName]: { screen: LoginScreen },
  [HomeScreen.routeName]: { screen: HomeScreen },
});

export default class App extends React.Component {
  render() {
    return (
      <KeyboardAvoidingView style={{ flex: 1 }} behavior="padding">
        <StackNavigator />
      </KeyboardAvoidingView>
    );
  }
}
```
