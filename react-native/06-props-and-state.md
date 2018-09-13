# この章の目標

- [ ] Reactコンポーネントの状態管理の仕組みを理解する
- [ ] PropsとStateの特性を理解する
- [ ] 画面を越えた状態の受け渡し方を理解する(ReactNavigation)

## Props

PropsはReactコンポーネントに渡す引数を指します

### 渡す側

```typescript
class App extends React.Component{
  render(){
    //JSXリテラルで指定されるものがProps(name&iconUrl)
    <Person  name={name} iconUrl={icon.url} />
  }
}
```

### 受け取り側

Propsは`construcor`の引数かそれ以外の関数では`this.props`で参照できます。  
自分自身のPropsを更新することは出来ませんが、親コンポーネントが新しいPropsを再度受け渡すことがあります。その場合`componentDidUpdate `が呼ばれます。

```typescript
interface Props {
 name: string;
 iconUrl: string;
}

class Person extends React.Component<Props> {
  constructor(props: Props){
    super(props);
    const name = props.name;
  }
  componentDidUpdate(prevProps: Props){
     if(this.props.name !== prevProps.name) { 
        // do something.
     }
  }
}
```

# State

Stateは名前の通りコンポーネントの状態を管理するオブジェクトです。コンポーネントはStateの変更を検知すると再描画する仕組みになっています。  

```typescript
interface Props {
  id: number;
}
interface State {
 isLoading: boolean;
 name?: string;
 iconUrl?: string;
}

class Person extends React.Component<Props> {
  constructor(props: Props){
    super(props);
    this.state = { isLoading: true }; //初期化はコンストラクタで直接代入する
  }
  async componentDidMount() {
     const response = await fetch(`https:exmaple.com/users/${this.props.id}`);
     const {name, iconUrl} = await response.json();
     this.setState({name, iconUrl, isLoading: false}); //状態の更新はthis.setState経由で行う
  }
  render() {
    if(this.state.isLoading) { // Stateを参照する場合は直接アクセス出来る
      return <LoadingView>
    } else {
      const {name, iconUrl} = this.state;
      return <ProfileRow name={name} iconUrl={iconUrl} />
    }
  }
}
```


# Navigation.State

画面間で値を受け渡したい時はNavigation.Stateの仕組みを利用します。これはReactNavigationの提供する機能です。
`navigation.navigate` する際にparamプロパティを渡すと遷移先のコンポーネントでは`props.navigation.state.params`からアクセスが可能です。

```typescript
const params = {userName: this.state.userName}
this.props.navigation.navigate({ routeName: HomeScreen.routeName, params }); // 受け渡し側
```

```typescript
import { NavigationScreenProp, NavigationRoute} from 'react-navigation';
//...
type Navigation = NavigationScreenProp<NavigationRoute<any>, any>; //Props型が複雑なためaliasを作成
interface Props {
  navigation: Navigation; 
}

class HomeScreen extends React.Component<Props> {
  constructor(props: Props) {
    super(props);
    const userName = props.navigation.state.params.userName; //受け取り側
  }
}
```

# [課題6-1]: 画面間での値の受け渡し(10min)

ログイン画面から遷移した先で入力したユーザー名を画面に表示させて下さい。

### スクリーンショット

| iOS | Android |
| :---: | :----: |
| <img src="images/06-01.gif" width=400 /> | <img src="images/06-02.gif" width=400 /> |
