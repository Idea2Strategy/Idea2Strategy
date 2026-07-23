import { useMemo, useState } from 'react';
import { Bell, LineChart, Moon, Plus, Search, Sun, X } from 'lucide-react';
import i2sLogo from './assets/i2s-logo.svg';
import { notifications } from './data/mockData.js';
import { navItems, utilityItems } from './lib/navigation.js';
import { LanguageProvider, Localized, useLanguage } from './lib/i18n.jsx';
import { BasicEditor, ProEditor, StrategyHome } from './views/StrategyViews.jsx';
import { BacktestView, BotsView, RoomsView } from './views/OperationsViews.jsx';
import { AccountView, AdminView } from './views/SupportViews.jsx';
import { DesignConceptLab } from './views/DesignConceptLab.jsx';
import './styles/tokens.css';
import './styles/base.css';
import './styles/balanced.css';
import './styles/concepts.css';

function Topbar({ theme, setTheme, page, setPage }) {
  const { language, setLanguage } = useLanguage();
  const [openPanel, setOpenPanel] = useState(null);
  const [watchlist, setWatchlist] = useState([
    { symbol: 'AAPL', change: '+1.24%' },
    { symbol: 'MSFT', change: '-0.38%' },
  ]);
  const labels = { strategy: 'STRATEGIES', bots: 'BOTS', backtest: 'BACKTEST', rooms: 'COMPETITION' };
  const togglePanel = (panel) => setOpenPanel((current) => current === panel ? null : panel);
  const addNvda = () => setWatchlist((current) => (
    current.some((item) => item.symbol === 'NVDA')
      ? current
      : [...current, { symbol: 'NVDA', change: '+0.82%' }]
  ));

  return <Localized><header className="app-topbar signal-product-nav">
    <div className="signal-product-brand">
      <img src={i2sLogo} alt="Idea2Strategy" />
      <strong>IDEA<span>2</span>STRATEGY</strong>
    </div>
    <nav aria-label="Signal 주요 메뉴" data-orientation="horizontal">
      {navItems.map(({ id, label }) => <button
        key={id}
        className={page === id ? 'active' : ''}
        aria-label={label}
        onClick={() => setPage(id)}
      >{labels[id]}</button>)}
    </nav>
    <div className="signal-nav-tools">
      <label className="global-search">
        <Search size={15} />
        <input aria-label="전체 검색" placeholder="SEARCH" />
      </label>
      <div className="topbar-popover-anchor">
        <button className="icon-button" aria-label="관심종목 설정" onClick={() => togglePanel('watchlist')}><LineChart size={17} /></button>
        {openPanel === 'watchlist' && <section className="topbar-popover watchlist-popover" role="dialog" aria-label="관심종목">
          <header><div><strong>관심종목</strong><span>내가 고른 종목만 표시</span></div><button aria-label="관심종목 닫기" onClick={() => setOpenPanel(null)}><X size={15} /></button></header>
          <div className="watchlist-items">{watchlist.map((item) => <div key={item.symbol}><span><strong>{item.symbol}</strong><small>사용자 설정</small></span><b className={item.change.startsWith('-') ? 'negative' : 'positive'}>{item.change}</b></div>)}</div>
          <button className="popover-add" aria-label="NVDA 추가" onClick={addNvda}><Plus size={14} /> NVDA 추가</button>
        </section>}
      </div>
      <div className="topbar-popover-anchor">
        <button className="icon-button has-count" aria-label="알림" onClick={() => togglePanel('notifications')}><Bell size={17} /><b>2</b></button>
        {openPanel === 'notifications' && <section className="topbar-popover notifications-popover" role="dialog" aria-label="최근 알림">
          <header><div><strong>최근 알림</strong><span>읽지 않음 2개</span></div><button aria-label="알림 닫기" onClick={() => setOpenPanel(null)}><X size={15} /></button></header>
          <div>{notifications.slice(0, 3).map((item) => <button className={item.unread ? 'unread' : ''} key={item.title}><i /><span><strong>{item.title}</strong><small>{item.time}</small></span></button>)}</div>
        </section>}
      </div>
      {utilityItems.map(({ id, label, icon: Icon }) => <button key={id} className={`icon-button ${page === id ? 'active' : ''}`} aria-label={label} onClick={() => setPage(id)}><Icon size={16} /></button>)}
      <button className="icon-button" aria-label={theme === 'light' ? '다크 모드' : '라이트 모드'} onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>{theme === 'light' ? <Moon size={17} /> : <Sun size={17} />}</button>
      <label className="language-select">
        <span className="sr-only">언어 선택</span>
        <select aria-label="언어 선택" value={language} onChange={(event) => setLanguage(event.target.value)}>
          <option value="ko">KO</option>
          <option value="en">EN</option>
        </select>
      </label>
      <button className="signal-user" aria-label="프로필">KIM <i /></button>
    </div>
  </header></Localized>;
}

function StrategySubnav({ openEditor, mode }) {
  return <Localized><div className="strategy-subnav"><span>EDITOR</span><button className={mode === 'basic' ? 'active' : ''} onClick={() => openEditor('basic')}>Basic 편집기</button><button className={mode === 'pro' ? 'active' : ''} onClick={() => openEditor('pro')}>Pro 편집기</button></div></Localized>;
}

function ProductApp() {
  if (typeof window !== 'undefined' && window.location.pathname.startsWith('/concepts')) {
    return <DesignConceptLab />;
  }

  const [theme, setTheme] = useState('dark');
  const [page, setPageState] = useState('strategy');
  const [strategyMode, setStrategyMode] = useState('home');

  const setPage = (next) => {
    setPageState(next);
    if (next !== 'strategy') setStrategyMode('home');
  };
  const openEditor = (mode) => {
    setPageState('strategy');
    setStrategyMode(mode);
  };

  const content = useMemo(() => {
    if (page === 'strategy') {
      if (strategyMode === 'basic') return <BasicEditor goBack={() => setStrategyMode('home')} />;
      if (strategyMode === 'pro') return <ProEditor goBack={() => setStrategyMode('home')} />;
      return <StrategyHome openEditor={openEditor} />;
    }
    if (page === 'bots') return <BotsView />;
    if (page === 'backtest') return <BacktestView />;
    if (page === 'rooms') return <RoomsView />;
    if (page === 'account') return <AccountView />;
    return <AdminView />;
  }, [page, strategyMode]);

  return <main
    data-testid="app-shell"
    data-variant="signal"
    data-design="signal-studio"
    data-theme={theme}
    className={`app-shell variant-balanced signal-product theme-${theme}`}
  >
    <div className="app-main">
      <Topbar theme={theme} setTheme={setTheme} page={page} setPage={setPage} />
      {page === 'strategy' && strategyMode !== 'home' && <StrategySubnav openEditor={openEditor} mode={strategyMode} />}
      <div className="page-scroll">{content}</div>
    </div>
  </main>;
}

export function App() {
  return <LanguageProvider><ProductApp /></LanguageProvider>;
}
