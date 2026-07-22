import { useMemo, useState } from 'react';
import { ChevronDown, CircleUserRound, Command, Moon, PanelLeftClose, Search, Sun, Zap } from 'lucide-react';
import { ticker } from './data/mockData.js';
import { navItems, utilityItems, variantFromLocation } from './lib/navigation.js';
import { BasicEditor, ProEditor, StrategyHome } from './views/StrategyViews.jsx';
import { BacktestView, BotsView, RoomsView } from './views/OperationsViews.jsx';
import { AccountView, AdminView, NotificationsView } from './views/SupportViews.jsx';
import './styles/tokens.css';
import './styles/base.css';
import './styles/balanced.css';
import './styles/terminal.css';

function Sidebar({ page, setPage, variant }) {
  const allItems = [...navItems, ...utilityItems];
  return <aside className="app-sidebar"><div className="brand"><span className="brand-mark"><Zap size={18} /></span><span><strong>IDEA<span>2</span>STRATEGY</strong><small>SIMULATION OS</small></span></div><nav aria-label="주요 메뉴">{navItems.map(({ id, label, icon: Icon, count }) => <button key={id} className={page === id ? 'active' : ''} aria-label={label} onClick={() => setPage(id)}><Icon size={18} /><span>{label}</span>{count && <b>{count}</b>}</button>)}</nav><div className="sidebar-bottom">{utilityItems.map(({ id, label, icon: Icon }) => <button key={id} className={page === id ? 'active' : ''} aria-label={label} onClick={() => setPage(id)}><Icon size={18} /><span>{label}</span></button>)}<div className="profile-chip"><CircleUserRound size={27} /><span><strong>김전략</strong><small>PRO MEMBER</small></span><ChevronDown size={14} /></div></div><span className="sidebar-variant">{variant === 'balanced' ? 'ATLAS NAV' : 'PULSE RAIL'}</span></aside>;
}

function Topbar({ variant, setVariant, theme, setTheme }) {
  const nextLabel = variant === 'balanced' ? '터미널형 보기' : '균형형 보기';
  return <header className="app-topbar"><button className="sidebar-toggle" aria-label="메뉴 접기"><PanelLeftClose size={18} /></button><label className="global-search"><Search size={16} /><input aria-label="전체 검색" placeholder="전략, 봇, 방 검색" /><kbd>⌘ K</kbd></label><div className="market-ticker">{ticker.map(([name, value, change]) => <span key={name}><small>{name}</small><strong>{value}</strong><i className={change.startsWith('-') ? 'negative' : change.startsWith('+') ? 'positive' : ''}>{change}</i></span>)}</div><div className="top-actions"><button className="icon-button" aria-label={theme === 'light' ? '다크 모드' : '라이트 모드'} onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>{theme === 'light' ? <Moon size={17} /> : <Sun size={17} />}</button><button className="variant-switch" onClick={() => setVariant(variant === 'balanced' ? 'terminal' : 'balanced')}><Command size={15} /><span>{nextLabel}</span></button></div></header>;
}

function StrategySubnav({ openEditor, mode }) {
  return <div className="strategy-subnav"><span>EDITOR</span><button className={mode === 'basic' ? 'active' : ''} onClick={() => openEditor('basic')}>Basic 편집기</button><button className={mode === 'pro' ? 'active' : ''} onClick={() => openEditor('pro')}>Pro 편집기</button></div>;
}

export function App({ initialVariant }) {
  const defaultVariant = initialVariant ?? variantFromLocation(typeof window === 'undefined' ? '' : window.location.pathname);
  const [variant, setVariantState] = useState(defaultVariant);
  const [theme, setTheme] = useState('light');
  const [page, setPageState] = useState('strategy');
  const [strategyMode, setStrategyMode] = useState('home');

  const setPage = (next) => { setPageState(next); if (next !== 'strategy') setStrategyMode('home'); };
  const openEditor = (mode) => { setPageState('strategy'); setStrategyMode(mode); };
  const setVariant = (next) => {
    setVariantState(next);
    if (typeof window !== 'undefined') window.history.replaceState({}, '', `/${next}`);
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
    if (page === 'notifications') return <NotificationsView />;
    if (page === 'account') return <AccountView />;
    return <AdminView />;
  }, [page, strategyMode]);

  return <main data-testid="app-shell" data-variant={variant} data-theme={theme} className={`app-shell variant-${variant} theme-${theme}`}><Sidebar page={page} setPage={setPage} variant={variant} /><div className="app-main"><Topbar variant={variant} setVariant={setVariant} theme={theme} setTheme={setTheme} /><div className="variant-banner"><span>{variant === 'balanced' ? 'BALANCED / ATLAS' : 'TERMINAL / PULSE'}</span><small>{variant === 'balanced' ? '여백과 흐름 중심' : '밀도와 모니터링 중심'}</small></div>{page === 'strategy' && <StrategySubnav openEditor={openEditor} mode={strategyMode} />}<div className="page-scroll">{content}</div></div></main>;
}
