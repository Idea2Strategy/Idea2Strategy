import { useMemo, useState } from 'react';
import {
  ArrowRight, BarChart3, Bell, Bot, ChevronRight, CirclePlus, Clock3,
  Command, LayoutGrid, MoreHorizontal, Play, Search, Settings2, Sparkles,
  Target, TrendingUp, Trophy, WalletCards,
} from 'lucide-react';
import i2sLogo from '../assets/i2s-logo.svg';

const concepts = [
  { id: 'atlas', key: 'A', name: 'Atlas Editorial', note: '밝고 선명한 편집형' },
  { id: 'flow', key: 'B', name: 'Flow Canvas', note: '부드럽고 여유로운 캔버스형' },
  { id: 'signal', key: 'C', name: 'Signal Studio', note: '집중도 높은 분석형' },
  { id: 'ledger', key: 'D', name: 'Ledger Mono', note: '절제된 편집·장부형' },
  { id: 'orbit', key: 'E', name: 'Orbit Glass', note: '공간감 있는 글래스형' },
  { id: 'tactile', key: 'F', name: 'Core Interface', note: '고대비 클린 인터페이스' },
];

const palettes = {
  atlas: [
    { id: 'mint', label: 'Mint', color: '#49b99a' },
    { id: 'ocean', label: 'Ocean', color: '#448bc1' },
    { id: 'coral', label: 'Coral', color: '#e36f5c' },
  ],
  flow: [
    { id: 'sage', label: 'Sage', color: '#4c9d82' },
    { id: 'lavender', label: 'Lavender', color: '#8d7ac5' },
    { id: 'apricot', label: 'Apricot', color: '#d89157' },
  ],
  signal: [
    { id: 'dark-lime', label: 'Dark Lime', color: '#d9ff63' },
    { id: 'light-mint', label: 'Light Mint', color: '#28a883' },
    { id: 'light-blue', label: 'Light Blue', color: '#377fc1' },
  ],
  ledger: [
    { id: 'red-ink', label: 'Red Ink', color: '#d73d32' },
    { id: 'cobalt', label: 'Cobalt', color: '#315fd1' },
    { id: 'forest', label: 'Forest', color: '#28735a' },
  ],
  orbit: [
    { id: 'cyan', label: 'Cyan', color: '#5ce2dc' },
    { id: 'violet', label: 'Violet', color: '#a989ff' },
    { id: 'solar', label: 'Solar', color: '#ffbd59' },
  ],
  tactile: [
    { id: 'core-cyan', label: 'Cyan', color: '#22d3ee' },
    { id: 'core-violet', label: 'Violet', color: '#a78bfa' },
    { id: 'core-amber', label: 'Amber', color: '#fbbf24' },
  ],
};

const strategies = [
  { name: '나스닥 추세 추종', assets: 'QQQ · TQQQ', state: '준비 완료', return: '+18.4%', updated: '12분 전', tone: 'lime' },
  { name: '배당 성장 리밸런싱', assets: 'SCHD · VIG', state: '준비 완료', return: '+9.7%', updated: '어제', tone: 'blue' },
  { name: '변동성 돌파 실험', assets: 'SPY · VIXY', state: '미완성', return: '—', updated: '3일 전', tone: 'violet' },
  { name: '반도체 모멘텀', assets: 'NVDA · SOXX', state: '준비 완료', return: '+22.1%', updated: '5일 전', tone: 'orange' },
];

const activity = [
  ['나스닥 추세 추종', '백테스트 완료', '+18.4%'],
  ['S&P 방어형', '봇 실행 중', '정상'],
  ['Summer Alpha', 'Competition', '12위'],
];

function Logo({ compact = false }) {
  return <div className="dc-logo"><img src={i2sLogo} alt="Idea2Strategy" />{!compact && <strong>idea<span>2</span>strategy</strong>}</div>;
}

function MiniChart({ type = 'up' }) {
  const points = type === 'up' ? '0,34 22,29 44,31 65,18 86,22 108,7 132,12 158,1' : '0,12 25,18 49,9 75,23 100,19 126,29 158,22';
  return <svg className="dc-sparkline" viewBox="0 0 160 38" aria-hidden="true"><polyline points={points} fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

function StrategySearch({ value, onChange, compact = false }) {
  return <label className={`dc-search ${compact ? 'compact' : ''}`}><Search size={16} /><input type="search" aria-label="전략 검색" value={value} onChange={(event) => onChange(event.target.value)} placeholder="전략 이름이나 종목 검색" /><kbd>⌘ K</kbd></label>;
}

function AtlasNav({ page, setPage }) {
  return <aside className="atlas-nav">
    <Logo compact />
    <nav aria-label="Atlas 메뉴">
      <button className={page === 'home' ? 'active' : ''} onClick={() => setPage('home')} aria-label="메인 페이지 보기"><LayoutGrid /></button>
      <button className={page === 'strategy' ? 'active' : ''} onClick={() => setPage('strategy')} aria-label="전략 페이지 보기"><Target /></button>
      <button><Bot /></button><button><BarChart3 /></button><button><Trophy /></button>
    </nav>
    <button className="atlas-avatar">김</button>
  </aside>;
}

function AtlasHome({ setPage }) {
  return <div className="atlas-page">
    <header className="atlas-header"><div><span className="eyebrow">THURSDAY · JUL 23</span><h1>오늘의 투자 흐름</h1><p>필요한 변화만 짧게 확인하세요.</p></div><div className="dc-header-actions"><button><Search /></button><button className="has-dot"><Bell /></button><button className="primary" onClick={() => setPage('strategy')}><CirclePlus /> 새 전략</button></div></header>
    <section className="atlas-hero">
      <div className="atlas-hero-copy"><span className="eyebrow">ACTIVE CAPITAL</span><strong>₩ 24,860,000</strong><div><b>+2.84%</b><span>이번 달</span></div></div>
      <div className="atlas-hero-chart"><MiniChart /><span>JUL 01</span><span>JUL 23</span></div>
      <div className="atlas-hero-side"><span>활성 봇</span><strong>3</strong><small>모두 정상 작동 중</small><div className="avatar-row"><i>Q</i><i>S</i><i>N</i></div></div>
    </section>
    <section className="atlas-grid">
      <article className="atlas-focus"><header><span className="eyebrow">FOCUS</span><button><MoreHorizontal /></button></header><h2>나스닥 추세 추종</h2><p><b>1시간봉</b> 기준으로 상승 흐름을 감지해 진입합니다.</p><div className="atlas-focus-metrics"><span><small>백테스트</small><strong>+18.4%</strong></span><span><small>최대 낙폭</small><strong>-6.2%</strong></span></div><button className="text-link" onClick={() => setPage('strategy')}>전략 열기 <ArrowRight /></button></article>
      <article className="atlas-activity"><header><div><span className="eyebrow">RECENT</span><h2>최근 움직임</h2></div><button>전체 보기</button></header>{activity.map(([title, desc, value]) => <div className="activity-row" key={title}><i /><span><strong>{title}</strong><small>{desc}</small></span><b>{value}</b><ChevronRight /></div>)}</article>
      <article className="atlas-competition"><span className="eyebrow">COMPETITION</span><div><Trophy /><span><strong>Summer Alpha</strong><small>종료까지 8일</small></span><b>12<small>/ 148</small></b></div><div className="progress"><i /></div></article>
    </section>
  </div>;
}

function AtlasStrategy({ query, setQuery }) {
  return <div className="atlas-page atlas-strategy">
    <header className="atlas-header"><div><span className="eyebrow">STRATEGY LIBRARY</span><h1>나의 전략</h1><p>만든 전략을 찾고, 상태를 확인하고, 이어서 편집하세요.</p></div><button className="primary"><CirclePlus /> 새 전략</button></header>
    <div className="atlas-toolbar"><StrategySearch value={query} onChange={setQuery} /><div><button className="active">전체 4</button><button>준비 완료 3</button><button>미완성 1</button><button aria-label="필터"><Settings2 /></button></div></div>
    <StrategyList query={query} variant="atlas" />
  </div>;
}

function FlowNav({ page, setPage }) {
  return <header className="flow-nav"><Logo /><nav aria-label="Flow 메뉴"><button className={page === 'home' ? 'active' : ''} onClick={() => setPage('home')} aria-label="메인 페이지 보기">홈</button><button className={['strategy', 'create'].includes(page) ? 'active' : ''} onClick={() => setPage('strategy')} aria-label="전략 페이지 보기">전략</button><button className={page === 'bots' ? 'active' : ''} onClick={() => setPage('bots')}>봇</button><button className={page === 'backtest' ? 'active' : ''} onClick={() => setPage('backtest')}>백테스트</button><button className={page === 'competition' ? 'active' : ''} onClick={() => setPage('competition')}>Competition</button></nav><div><button><Search /></button><button><Bell /></button><button className="flow-avatar">김</button></div></header>;
}

function FlowHome({ setPage }) {
  return <div className="flow-page">
    <section className="flow-welcome"><span>좋은 아침이에요, 김전략님</span><h1>시장은 움직이고,<br />전략은 차분하게.</h1><p>3개의 봇이 계획대로 움직이고 있어요.</p><button onClick={() => setPage('strategy')}>전략 둘러보기 <ArrowRight /></button></section>
    <section className="flow-bento">
      <article className="flow-balance"><header><span><small>이번 달 자산 변화</small><strong>+ ₩ 686,200</strong></span><span className="positive-pill">+2.84%</span></header><div className="flow-chart"><MiniChart /><i /><i /><i /></div><footer><span>7월 1일</span><span>오늘</span></footer></article>
      <article className="flow-bot"><div className="soft-icon"><Play /></div><span><small>지금 실행 중</small><strong>S&P 방어형 봇</strong></span><b>정상</b><p>다음 평가 <strong>14:30</strong></p></article>
      <article className="flow-strategy-card"><span className="eyebrow">RECENT STRATEGY</span><h2>나스닥<br />추세 추종</h2><div><span>QQQ</span><span>TQQQ</span></div><button onClick={() => setPage('strategy')}><ArrowRight /></button></article>
      <article className="flow-score"><span>Summer Alpha</span><strong>12<small>위</small></strong><p>상위 8%</p><div className="rank-bar"><i /></div></article>
    </section>
  </div>;
}

function FlowStrategy({ query, setQuery, setPage }) {
  return <div className="flow-page flow-strategy">
    <section className="flow-strategy-heading"><span>전략 캔버스</span><h1>아이디어를<br />다시 이어가세요.</h1><div><StrategySearch value={query} onChange={setQuery} compact /><button className="flow-create" onClick={() => setPage('create')}><CirclePlus /> 새 전략 만들기</button></div></section>
    <section className="flow-gallery"><StrategyList query={query} variant="flow" /></section>
  </div>;
}

function SignalNav({ page, setPage }) {
  return <header className="signal-nav"><Logo /><nav aria-label="Signal 메뉴"><button className={page === 'home' ? 'active' : ''} onClick={() => setPage('home')} aria-label="메인 페이지 보기">OVERVIEW</button><button className={['strategy', 'create'].includes(page) ? 'active' : ''} onClick={() => setPage('strategy')} aria-label="전략 페이지 보기">STRATEGIES</button><button className={page === 'bots' ? 'active' : ''} onClick={() => setPage('bots')}>BOTS</button><button className={page === 'backtest' ? 'active' : ''} onClick={() => setPage('backtest')}>BACKTEST</button><button className={page === 'competition' ? 'active' : ''} onClick={() => setPage('competition')}>COMPETITION</button></nav><div><button><Command /></button><button className="signal-profile"><i /> KIM</button></div></header>;
}

function SignalHome({ setPage }) {
  return <div className="signal-page">
    <header className="signal-title"><div><span>OVERVIEW / 07.23</span><h1>OPERATING<br />CLEARLY.</h1></div><p>전략 4 · 활성 봇 3<br /><b>모든 시스템 정상</b></p></header>
    <section className="signal-grid">
      <article className="signal-performance"><header><span>PORTFOLIO PULSE</span><b>LIVE</b></header><div><strong>+2.84<small>%</small></strong><span>MONTH TO DATE</span></div><MiniChart /><footer><span>₩ 24.86M 운용 중</span><span>S&P 500 +1.12%</span></footer></article>
      <article className="signal-system"><header><span>SYSTEM STATUS</span><i /></header>{[['S&P 방어형', 'RUNNING'], ['나스닥 추세', 'STANDBY'], ['배당 리밸런싱', 'RUNNING']].map(([name, state]) => <div key={name}><span><i />{name}</span><b>{state}</b></div>)}</article>
      <article className="signal-alpha"><span>TOP SIGNAL</span><strong>NVDA</strong><div><TrendingUp /><b>+3.62%</b></div><small>반도체 모멘텀</small></article>
      <article className="signal-action"><span>NEXT ACTION</span><h2>검토할 전략<br />1개가 있습니다.</h2><button onClick={() => setPage('strategy')}>OPEN DESK <ArrowRight /></button></article>
    </section>
  </div>;
}

function SignalStrategy({ query, setQuery, setPage }) {
  return <div className="signal-page signal-strategy">
    <header className="signal-strategy-header"><div><span>STRATEGY DESK</span><h1>04 / LIBRARY</h1></div><div><StrategySearch value={query} onChange={setQuery} compact /><button onClick={() => setPage('create')}><CirclePlus /> NEW STRATEGY</button></div></header>
    <div className="signal-summary"><span><small>READY</small><strong>03</strong></span><span><small>INCOMPLETE</small><strong>01</strong></span><span><small>AVG. RETURN</small><strong>+16.7%</strong></span><span><small>LAST UPDATED</small><strong>12 MIN</strong></span></div>
    <StrategyList query={query} variant="signal" />
  </div>;
}

function LedgerNav({ page, setPage }) {
  return <aside className="ledger-nav"><Logo /><div className="ledger-index">I2S / 05</div><nav aria-label="Ledger 메뉴"><button className={page === 'home' ? 'active' : ''} onClick={() => setPage('home')} aria-label="메인 페이지 보기"><span>01</span>Overview</button><button className={page === 'strategy' ? 'active' : ''} onClick={() => setPage('strategy')} aria-label="전략 페이지 보기"><span>02</span>Strategies</button><button><span>03</span>Bots</button><button><span>04</span>Backtest</button><button><span>05</span>Competition</button></nav><footer><span>SEOUL</span><strong>2026.07.23</strong></footer></aside>;
}

function LedgerHome({ setPage }) {
  return <div className="ledger-page">
    <header className="ledger-header"><span>DAILY PORTFOLIO / 09:42 KST</span><div><button><Search /></button><button><Bell /></button><button className="ledger-primary" onClick={() => setPage('strategy')}>새 전략 <ArrowRight /></button></div></header>
    <section className="ledger-intro"><div><span>ISSUE NO. 023</span><h1>숫자는 차분하게,<br />결정은 선명하게.</h1></div><p>오늘 확인할 변화는 <b>세 가지</b>입니다.<br />나머지는 계획대로 움직이고 있습니다.</p></section>
    <section className="ledger-balance"><div><span>운용 자산</span><strong>₩24,860,000</strong><small>JUL 01 — JUL 23</small></div><div className="ledger-line"><MiniChart /><span>+2.84%</span></div></section>
    <section className="ledger-columns">
      <article><span>01 / ACTIVE</span><h2>S&P 방어형</h2><p>봇 3개가 정상 작동 중입니다.</p><footer><b>RUNNING</b><ArrowRight /></footer></article>
      <article><span>02 / REVIEW</span><h2>변동성 돌파 실험</h2><p>매수 조건 한 곳이 비어 있습니다.</p><footer><b>INCOMPLETE</b><ArrowRight /></footer></article>
      <article><span>03 / RANK</span><h2>Summer Alpha</h2><p>148명 중 현재 순위입니다.</p><footer><strong>12</strong><small>TOP 8%</small></footer></article>
    </section>
  </div>;
}

function LedgerStrategy({ query, setQuery }) {
  return <div className="ledger-page ledger-strategy">
    <header className="ledger-header"><span>STRATEGY REGISTER</span><button className="ledger-primary"><CirclePlus /> 새 전략</button></header>
    <section className="ledger-strategy-title"><div><span>04 ENTRIES / PRIVATE</span><h1>전략 장부</h1></div><StrategySearch value={query} onChange={setQuery} compact /></section>
    <StrategyList query={query} variant="ledger" />
  </div>;
}

function OrbitNav({ page, setPage }) {
  return <header className="orbit-nav"><Logo /><nav aria-label="Orbit 메뉴"><button className={page === 'home' ? 'active' : ''} onClick={() => setPage('home')} aria-label="메인 페이지 보기">Home</button><button className={['strategy', 'create'].includes(page) ? 'active' : ''} onClick={() => setPage('strategy')} aria-label="전략 페이지 보기">Strategy</button><button className={page === 'bots' ? 'active' : ''} onClick={() => setPage('bots')}>Bots</button><button className={page === 'backtest' ? 'active' : ''} onClick={() => setPage('backtest')}>Backtest</button><button className={page === 'competition' ? 'active' : ''} onClick={() => setPage('competition')}>Competition</button></nav><div><button><Search /></button><button><Bell /></button><button className="orbit-avatar">K</button></div></header>;
}

function OrbitHome({ setPage }) {
  return <div className="orbit-page">
    <section className="orbit-hero"><div className="orbit-copy"><span>SYSTEM STATUS · ALL CLEAR</span><h1>전략이 궤도에<br />있습니다.</h1><p>중요한 신호만 가까이, 나머지는 조용히 운용합니다.</p><button onClick={() => setPage('strategy')}>전략 오비트 열기 <ArrowRight /></button></div><div className="orbit-visual"><div className="orbit-ring ring-one"><i /></div><div className="orbit-ring ring-two"><i /></div><div className="orbit-core"><Logo compact /><strong>+2.84%</strong><span>THIS MONTH</span></div><b className="orbit-tag tag-one">QQQ</b><b className="orbit-tag tag-two">SPY</b><b className="orbit-tag tag-three">NVDA</b></div></section>
    <section className="orbit-cards">
      <article><header><Bot /><span>ACTIVE BOTS</span></header><strong>03</strong><p>모두 계획대로 실행 중</p><div className="orbit-status"><i /><i /><i /></div></article>
      <article><header><Sparkles /><span>RECENT SIGNAL</span></header><h2>나스닥 추세 추종</h2><p>QQQ · 1시간봉 · 매수 대기</p><footer><span>CONFIDENCE</span><b>84%</b></footer></article>
      <article><header><Trophy /><span>COMPETITION</span></header><strong>12<small>위</small></strong><p>Summer Alpha · 상위 8%</p><div className="orbit-progress"><i /></div></article>
    </section>
  </div>;
}

function OrbitStrategy({ query, setQuery, setPage }) {
  return <div className="orbit-page orbit-strategy">
    <header className="orbit-strategy-title"><div><span>PRIVATE WORKSPACE · 04</span><h1>전략 오비트</h1></div><div><StrategySearch value={query} onChange={setQuery} compact /><button onClick={() => setPage('create')}><CirclePlus /> 새 전략</button></div></header>
    <StrategyList query={query} variant="orbit" />
  </div>;
}

function ConceptBotsPage({ family }) {
  const [group, setGroup] = useState('personal');
  return <div className={`extended-page ${family}-page`}>
    <header className="extended-heading"><div><span>BOT OPERATIONS · 03 ACTIVE</span><h1>봇 운영</h1><p>개인 운용과 대회 참여 봇을 한곳에서 확인합니다.</p></div><button><CirclePlus /> 새 봇 연결</button></header>
    <div className="extended-segment" role="group" aria-label="봇 종류"><button className={group === 'personal' ? 'active' : ''} onClick={() => setGroup('personal')}>개인용</button><button className={group === 'competition' ? 'active' : ''} onClick={() => setGroup('competition')}>대회 참여</button></div>
    {group === 'personal' ? <section className="bot-grid">
      {[['S&P 방어형', 'SPY · BIL', '+4.8%', 'RUNNING'], ['나스닥 추세', 'QQQ · TQQQ', '+18.4%', 'RUNNING'], ['배당 리밸런싱', 'SCHD · VIG', '+9.7%', 'PAUSED']].map(([name, assets, value, state]) => <article key={name}><header><i /><span>{state}</span></header><Bot /><h2>{name}</h2><p>{assets}</p><footer><span>누적 수익</span><strong>{value}</strong></footer></article>)}
    </section> : <section className="competition-bot-group"><header><Trophy /><div><span>SUMMER ALPHA</span><h2>대회 참여 봇</h2></div><strong>12위</strong></header>{[['1', 'Alpha Wave', '+24.2%'], ['12', '나의 Orbit Bot', '+17.1%'], ['24', 'Momentum K', '+13.6%']].map(([rank, name, value]) => <div key={rank}><b>{rank}</b><span>{name}</span><strong>{value}</strong></div>)}</section>}
  </div>;
}

function ConceptBacktestPage({ family }) {
  const [period, setPeriod] = useState('1Y');
  return <div className={`extended-page ${family}-page`}>
    <header className="extended-heading"><div><span>ANALYSIS · S&P 500 BENCHMARK</span><h1>백테스트 분석</h1><p>위기 구간과 주문 로그를 함께 보며 전략을 검증합니다.</p></div><button>결과 내보내기 <ArrowRight /></button></header>
    <div className="extended-segment period" role="group" aria-label="백테스트 기간">{['3M', '6M', '1Y', '3Y'].map((item) => <button key={item} className={period === item ? 'active' : ''} onClick={() => setPeriod(item)}>{item}</button>)}</div>
    <section className="backtest-layout">
      <article className="backtest-chart"><header><div><span>나스닥 추세 추종</span><strong>+18.4%</strong></div><div><span>S&P 500</span><strong>+11.2%</strong></div></header><svg viewBox="0 0 760 260" aria-label={`${period} 백테스트 차트`}><path className="grid" d="M0 52H760M0 104H760M0 156H760M0 208H760" /><path className="benchmark" d="M0 220 C90 205,130 216,210 170 S340 180,410 132 S550 148,760 72" /><path className="strategy-line" d="M0 226 C75 210,130 238,205 185 S318 202,385 116 S530 170,600 82 S700 88,760 24" /></svg><footer><span><i /> 전략</span><span><i /> S&P 500</span></footer></article>
      <aside className="backtest-events"><span>주요 구간</span>{[['2020.03', 'COVID SHOCK', '-12.8%'], ['2022.06', 'RATE HIKE', '-7.4%'], ['2024.08', 'VOLATILITY', '+2.1%']].map(([date, title, value]) => <button key={date}><small>{date}</small><strong>{title}</strong><b>{value}</b></button>)}</aside>
    </section>
  </div>;
}

function ConceptCompetitionPage({ family }) {
  const [query, setQuery] = useState('');
  const rooms = [['Summer Alpha', '수익률', '148명', 'D-8'], ['Risk Control League', '샤프 지수', '82명', 'D-14'], ['ETF Rotation Cup', 'MDD 보정', '64명', 'D-21']];
  const filtered = rooms.filter((room) => room[0].toLowerCase().includes(query.toLowerCase()));
  return <div className={`extended-page ${family}-page`}>
    <header className="extended-heading"><div><span>PUBLIC ARENA · 03 OPEN</span><h1>Competition</h1><p>공식 대회와 참여 조건을 비교하고 바로 입장합니다.</p></div><button><Trophy /> 내 대회 보기</button></header>
    <section className="official-room"><span>OFFICIAL</span><div><Trophy /><span><h2>2026 Summer Alpha</h2><p>수익률 · 최대 낙폭 종합 평가</p></span><strong>₩10M<small>상금</small></strong><button>대회 보기 <ArrowRight /></button></div></section>
    <div className="competition-tools"><label><Search /><input aria-label="대회 검색" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="대회 검색" /></label><button>점수 방식</button><button>참여 인원</button></div>
    <section className="room-list">{filtered.map(([name, score, people, due]) => <button key={name}><span><i /><strong>{name}</strong></span><span>{score}</span><span>{people}</span><b>{due}</b><ArrowRight /></button>)}</section>
  </div>;
}

function ConceptCreatePage({ family, setPage }) {
  const [mode, setMode] = useState('basic');
  const [sell, setSell] = useState(false);
  const [assets, setAssets] = useState(['QQQ']);
  const toggleAsset = (asset) => setAssets((current) => current.includes(asset) ? current.filter((item) => item !== asset) : [...current, asset]);
  return <div className={`extended-page create-page ${family}-page`}>
    <header className="extended-heading"><div><span>NEW STRATEGY · DRAFT</span><h1>새 전략 만들기</h1><p>종목을 먼저 고르고 각 섹션에 매수·매도 조건을 연결합니다.</p></div><button onClick={() => setPage('strategy')}>나가기</button></header>
    <div className="create-mode" role="group" aria-label="전략 생성 방식"><button className={mode === 'basic' ? 'active' : ''} onClick={() => setMode('basic')}><strong>Basic</strong><span>질문에 답하며 만들기</span></button><button className={mode === 'pro' ? 'active' : ''} onClick={() => setMode('pro')}><strong>Pro</strong><span>직접 조건 구성하기</span></button><button><strong>가져오기</strong><span>기존 전략에서 시작</span></button></div>
    <section className="create-workspace">
      <aside><span>01 · 종목 선택</span><h2>함께 운용할 종목</h2><p>여러 종목은 같은 비율로 투자됩니다.</p><div>{['QQQ', 'TQQQ', 'SPY', 'NVDA'].map((asset) => <button key={asset} className={assets.includes(asset) ? 'active' : ''} onClick={() => toggleAsset(asset)}>{asset}<small>{assets.includes(asset) ? '선택됨' : '추가'}</small></button>)}</div></aside>
      <div className="strategy-section"><header><div><span>SECTION 01</span><h2>{assets.length ? assets.join(' · ') : '종목을 선택하세요'}</h2></div><b>동일 비중</b></header><article><span>매수 전략 · 필수</span><strong><TrendingUp /> 20일 이동평균선 상향 돌파</strong><p><b>1시간봉</b> 종가가 이동평균선을 위로 통과하면 매수 후보를 만듭니다.</p><button>조건 편집</button></article><article className={!sell ? 'optional' : ''}><span>매도 전략 · 선택</span>{sell ? <><strong><Target /> 수익률 12% 도달</strong><p>목표 수익에 도달하면 전량 매도합니다.</p></> : <p>매도 조건 없이도 전략을 저장할 수 있습니다.</p>}<button onClick={() => setSell(!sell)}>{sell ? '조건 제거' : '매도 조건 추가'}</button></article></div>
    </section>
    <footer className="create-footer"><span>{assets.length}개 종목 · {mode === 'basic' ? 'Basic' : 'Pro'} 모드</span><button onClick={() => setPage('strategy')}>전략 저장 <ArrowRight /></button></footer>
  </div>;
}

function TactileNav({ page, setPage }) {
  return <header className="core-nav"><div className="core-brand"><Logo compact /><span>Core Interface</span></div><nav aria-label="Core Interface 메뉴"><button className={page === 'home' ? 'active' : ''} onClick={() => setPage('home')}><LayoutGrid /> Home</button><button className={page === 'strategy' ? 'active' : ''} onClick={() => setPage('strategy')}><Target /> Strategy</button></nav><div><button><Bell /></button><button><Settings2 /></button><span>K</span></div></header>;
}

function CoreCard({ title, meta, children }) {
  return <section className="core-section"><header><h2>{title}</h2><span>{meta}</span></header><div className="core-card">{children}</div></section>;
}

function TactileHome({ setPage }) {
  return <div className="core-page">
    <TactileNav page="home" setPage={setPage} />
    <section className="core-intro"><span><i /> REAL-TIME · ENCRYPTED</span><h1>오늘의 전략 신호를<br />한 화면에.</h1><p>운용 흐름, 확인할 주문, 활성 전략을 하나의 조용한 인터페이스로 모았습니다.</p></section>
    <main className="core-grid">
      <div><CoreCard title="TIMELINE" meta="TODAY"><div className="core-timeline">{[['09:00', '시장 조건 스캔', '완료'], ['11:20', 'QQQ 매수 후보', '검토'], ['15:30', '리밸런싱 평가', '예정']].map(([time, title, state], index) => <button className={index === 1 ? 'active' : ''} key={time}><time>{time}</time><i /><span><strong>{title}</strong><small>{state}</small></span></button>)}</div></CoreCard><CoreCard title="MESSAGES" meta="2 NEW"><div className="core-messages"><button><i /><span><strong>백테스트가 완료됐습니다.</strong><small>나스닥 추세 추종 · +18.4%</small></span><time>10:42</time></button><button><i /><span><strong>주문 후보를 확인하세요.</strong><small>QQQ · 매수 1건</small></span><time>09:15</time></button></div></CoreCard></div>
      <CoreCard title="PENDING ACTIONS" meta="03"><div className="core-actions">{['QQQ 매수 후보 검토', 'Summer Alpha 봇 선택', '변동성 전략 조건 완성'].map((item, index) => <label key={item}><input type="checkbox" defaultChecked={index === 0} /><span>{item}</span></label>)}</div></CoreCard>
      <div><CoreCard title="ACTIVE MARKET" meta="LIVE"><div className="core-market"><span><i /><small>NASDAQ</small></span><strong>+1.28%</strong><MiniChart /></div></CoreCard><CoreCard title="VITALS" meta="NORMAL"><div className="core-vitals"><span><small>ACTIVE BOTS</small><strong>03</strong></span><span><small>CAPITAL</small><strong>₩24.8M</strong></span><button onClick={() => setPage('strategy')}>전략 열기 <ArrowRight /></button></div></CoreCard></div>
    </main>
  </div>;
}

function TactileStrategy({ query, setQuery, setPage }) {
  return <div className="core-page">
    <TactileNav page="strategy" setPage={setPage} />
    <section className="core-intro core-strategy-intro"><span><i /> STRATEGY INTERFACE</span><h1>준비된 전략과<br />다음 판단.</h1><div><StrategySearch value={query} onChange={setQuery} compact /><button onClick={() => setPage('home')}>Overview <ArrowRight /></button></div></section>
    <div className="core-strategy-summary"><span><small>READY</small><strong>03</strong></span><span><small>INCOMPLETE</small><strong>01</strong></span><span><small>AVG. RETURN</small><strong>+16.7%</strong></span></div>
    <section className="core-strategy-list">{strategies.filter((item) => `${item.name} ${item.assets}`.toLowerCase().includes(query.toLowerCase())).map((item, index) => <button key={item.name}><b>0{index + 1}</b><span><strong>{item.name}</strong><small>{item.assets}</small></span><span><i className={item.state === '미완성' ? 'warn' : ''} />{item.state}</span><strong>{item.return}</strong><ArrowRight /></button>)}</section>
  </div>;
}

function StrategyList({ query, variant }) {
  const filtered = useMemo(() => strategies.filter((item) => `${item.name} ${item.assets}`.toLowerCase().includes(query.toLowerCase())), [query]);
  if (!filtered.length) return <div className="dc-empty"><Search /><strong>찾는 전략이 없어요.</strong><span>다른 이름이나 종목으로 검색해 보세요.</span></div>;

  if (variant === 'flow') return <>{filtered.map((item, index) => <article className={`flow-item tone-${item.tone}`} key={item.name}><header><span>{item.state}</span><button><MoreHorizontal /></button></header><div className="flow-item-index">0{index + 1}</div><h2>{item.name}</h2><p>{item.assets}</p><footer><span><small>백테스트</small><strong>{item.return}</strong></span><button><ArrowRight /></button></footer></article>)}</>;
  if (variant === 'signal') return <section className="signal-table"><header><span>STRATEGY</span><span>ASSETS</span><span>STATUS</span><span>BACKTEST</span><span>UPDATED</span><i /></header>{filtered.map((item, index) => <button className="signal-row" key={item.name}><b>0{index + 1}</b><span><strong>{item.name}</strong><small>{item.assets}</small></span><span>{item.assets}</span><span><i className={item.state === '미완성' ? 'warn' : ''} />{item.state}</span><strong>{item.return}</strong><span>{item.updated}</span><ArrowRight /></button>)}</section>;
  if (variant === 'ledger') return <section className="ledger-list"><header><span>NO.</span><span>STRATEGY / ASSETS</span><span>STATUS</span><span>RETURN</span><span>UPDATED</span><i /></header>{filtered.map((item, index) => <button className="ledger-row" key={item.name}><b>{String(index + 1).padStart(2, '0')}</b><span><strong>{item.name}</strong><small>{item.assets}</small></span><span>{item.state}</span><strong>{item.return}</strong><span>{item.updated}</span><ArrowRight /></button>)}</section>;
  if (variant === 'orbit') return <section className="orbit-list">{filtered.map((item, index) => <button className={`orbit-item tone-${item.tone}`} key={item.name}><header><span>0{index + 1}</span><b>{item.state}</b></header><div className="orbit-item-symbol"><i /><i /><i /></div><h2>{item.name}</h2><p>{item.assets}</p><footer><span><small>BACKTEST</small><strong>{item.return}</strong></span><ArrowRight /></footer></button>)}</section>;
  if (variant === 'tactile') return <section className="tactile-list">{filtered.map((item, index) => <button className="tactile-item" key={item.name}><header><span>UNIT {String(index + 1).padStart(2, '0')}</span><div><i className={item.state === '미완성' ? 'warning' : ''} /><b>{item.state}</b></div></header><div className="tactile-item-body"><div className="tactile-screw" /><span><strong>{item.name}</strong><small>{item.assets}</small></span><div className="tactile-meter"><i style={{ width: item.return === '—' ? '16%' : `${54 + index * 9}%` }} /></div><em>{item.return}</em><div className="tactile-screw" /></div><footer><span>UPDATED {item.updated}</span><b>OPEN <ArrowRight /></b></footer></button>)}</section>;
  return <section className="atlas-list"><header><span>전략</span><span>상태</span><span>백테스트</span><span>최근 수정</span><i /></header>{filtered.map((item) => <button className="atlas-row" key={item.name}><span className="atlas-name-cell"><i className={`strategy-dot tone-${item.tone}`} /><span><strong>{item.name}</strong><small>{item.assets}</small></span></span><span><b className={item.state === '미완성' ? 'warn' : ''}>{item.state}</b></span><strong>{item.return}</strong><span><Clock3 /> {item.updated}</span><ArrowRight /></button>)}</section>;
}

function ExtendedRoute({ family, page, query, setQuery, setPage }) {
  if (page === 'bots') return <ConceptBotsPage family={family} />;
  if (page === 'backtest') return <ConceptBacktestPage family={family} />;
  if (page === 'competition') return <ConceptCompetitionPage family={family} />;
  if (page === 'create') return <ConceptCreatePage family={family} setPage={setPage} />;
  if (family === 'flow') return page === 'home' ? <FlowHome setPage={setPage} /> : <FlowStrategy query={query} setQuery={setQuery} setPage={setPage} />;
  if (family === 'signal') return page === 'home' ? <SignalHome setPage={setPage} /> : <SignalStrategy query={query} setQuery={setQuery} setPage={setPage} />;
  return page === 'home' ? <OrbitHome setPage={setPage} /> : <OrbitStrategy query={query} setQuery={setQuery} setPage={setPage} />;
}

export function DesignConceptLab() {
  const [concept, setConcept] = useState('atlas');
  const [page, setPage] = useState('home');
  const [query, setQuery] = useState('');
  const [paletteByConcept, setPaletteByConcept] = useState({
    atlas: 'mint',
    flow: 'sage',
    signal: 'dark-lime',
    ledger: 'red-ink',
    orbit: 'cyan',
    tactile: 'core-cyan',
  });

  const current = concepts.find((item) => item.id === concept);
  const activePalette = paletteByConcept[concept];
  const changePage = (next) => { setPage(next); setQuery(''); };
  const changePalette = (palette) => setPaletteByConcept((currentPalettes) => ({ ...currentPalettes, [concept]: palette }));

  return <main className="design-lab">
    <header className="design-lab-bar">
      <div><span>DESIGN LAB</span><strong>메인 · 전략 시안 비교</strong></div>
      <div className="concept-tabs" role="group" aria-label="디자인 시안">
        {concepts.map((item) => <button key={item.id} className={concept === item.id ? 'active' : ''} onClick={() => { setConcept(item.id); if (!['flow', 'signal', 'orbit'].includes(item.id) && !['home', 'strategy'].includes(page)) changePage('home'); }} aria-label={`${item.key} · ${item.name}`}><b>{item.key}</b><span>{item.name}<small>{item.note}</small></span></button>)}
      </div>
      <div className="lab-controls">
        <div className="palette-picker" role="group" aria-label={`${current.name} 색상 선택`}>
          <span>COLOR</span>
          {palettes[concept].map((palette) => <button key={palette.id} className={activePalette === palette.id ? 'active' : ''} onClick={() => changePalette(palette.id)} aria-label={`${palette.label} 색상`} title={palette.label}><i style={{ background: palette.color }} /></button>)}
        </div>
        <div className="page-tabs" role="group" aria-label="페이지 선택"><button className={page === 'home' ? 'active' : ''} onClick={() => changePage('home')} aria-label="메인 페이지 보기">메인</button><button className={['strategy', 'create'].includes(page) ? 'active' : ''} onClick={() => changePage('strategy')} aria-label="전략 페이지 보기">전략</button></div>
      </div>
    </header>
    <section className={`design-stage concept-${concept} palette-${activePalette}`} data-testid="design-concept" data-concept={concept} data-palette={activePalette} aria-label={`${current.name} ${page === 'home' ? '메인' : '전략'} 시안`}>
      {concept === 'atlas' && <div className="atlas-shell"><AtlasNav page={page} setPage={changePage} />{page === 'home' ? <AtlasHome setPage={changePage} /> : <AtlasStrategy query={query} setQuery={setQuery} />}</div>}
      {concept === 'flow' && <div className="flow-shell"><FlowNav page={page} setPage={changePage} /><ExtendedRoute family="flow" page={page} query={query} setQuery={setQuery} setPage={changePage} /></div>}
      {concept === 'signal' && <div className="signal-shell"><SignalNav page={page} setPage={changePage} /><ExtendedRoute family="signal" page={page} query={query} setQuery={setQuery} setPage={changePage} /></div>}
      {concept === 'ledger' && <div className="ledger-shell"><LedgerNav page={page} setPage={changePage} />{page === 'home' ? <LedgerHome setPage={changePage} /> : <LedgerStrategy query={query} setQuery={setQuery} />}</div>}
      {concept === 'orbit' && <div className="orbit-shell"><OrbitNav page={page} setPage={changePage} /><ExtendedRoute family="orbit" page={page} query={query} setQuery={setQuery} setPage={changePage} /></div>}
      {concept === 'tactile' && <div className="core-shell">{page === 'home' ? <TactileHome setPage={changePage} /> : <TactileStrategy query={query} setQuery={setQuery} setPage={changePage} />}</div>}
    </section>
  </main>;
}
