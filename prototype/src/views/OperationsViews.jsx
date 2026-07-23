import { useMemo, useState } from 'react';
import { Activity, ArrowUpRight, Bot, CalendarDays, CheckCircle2, ChevronDown, ChevronUp, Clock3, Coins, Medal, Play, Plus, RefreshCw, Search, Trophy, Users } from 'lucide-react';
import { AreaChart, BarList, MiniSpark } from '../components/charts.jsx';
import { Button, DataTable, HelpNote, PageHeading, Panel, StatCard, Status } from '../components/common.jsx';
import { bots, botSeries, equitySeries, leaderboard, monthlyFailures, positions, trades } from '../data/mockData.js';
import { Localized } from '../lib/i18n.jsx';

const botTone = (state) => state === '실행 중' || state === '평가 중' ? 'positive' : 'warning';

export function BotsView() {
  const botColumns = [
    { key: 'name', label: '봇', render: (row) => <span className="entity-cell"><span className="entity-icon"><Bot size={16} /></span><span><strong>{row.name}</strong><small>{row.room}</small></span></span> },
    { key: 'state', label: '상태', render: (row) => <Status tone={botTone(row.state)}>{row.state}</Status> },
    { key: 'capital', label: '총자산' },
    { key: 'change', label: '누적 수익률', render: (row) => <strong className={row.change.startsWith('+') ? 'positive' : 'negative'}>{row.change}</strong> },
    { key: 'strategies', label: '전략' },
  ];
  const positionColumns = [
    { key: 'symbol', label: '종목', render: (row) => <strong>{row.symbol}</strong> },
    { key: 'qty', label: '수량' }, { key: 'avg', label: '평균가' }, { key: 'price', label: '현재가' },
    { key: 'pnl', label: '평가손익', render: (row) => <span className="positive">{row.pnl}</span> }, { key: 'share', label: '비중' },
  ];
  return <Localized><div className="page"><PageHeading eyebrow="LIVE OPERATIONS" title="봇 운영 센터" description="서버에서 실행 중인 봇과 공식 가상 체결 상태를 확인합니다." actions={<><Button icon={RefreshCw}>새로고침</Button><Button kind="primary" icon={Plus}>봇 출시</Button></>} />
    <div className="stats-grid four"><StatCard label="실행 중" value="2 / 10" detail="최대 동시 운영" icon={Play} /><StatCard label="전체 가상자산" value="$54,016.60" detail="3개 봇 합계" trend="+1.11%" icon={Coins} /><StatCard label="오늘 체결" value="07" detail="개별 체결 기준" icon={CheckCircle2} /><StatCard label="확인 기한" value="D−18" detail="Atlas 07 계속 실행" icon={Clock3} /></div>
    <div className="content-grid operations-grid"><Panel className="span-2" title="운영 자산" subtitle="Atlas 07 · 미국 동부 시각 기준" action={<span className="live-pill"><i /> MARKET OPEN</span>}><div className="chart-summary"><strong>$24,892.40</strong><span className="positive">+$450.18 · 1.84%</span></div><AreaChart values={botSeries} label="Atlas 07 자산 변화" /></Panel><Panel title="봇 상태" subtitle="실행·평가·조치 상태"><DataTable columns={botColumns} rows={bots} /></Panel><Panel className="span-2" title="현재 포지션" subtitle="공식 가상 체결 원장 기준"><DataTable columns={positionColumns} rows={positions} /></Panel><Panel title="최근 판단" subtitle="실시간 노드 실행은 표시하지 않습니다"><div className="event-list"><div><span className="event-dot positive" /><strong>SPY 주문 체결</strong><small>10:14:08 ET · 12주</small></div><div><span className="event-dot" /><strong>예산 상한 검사 통과</strong><small>10:14:02 ET · Opening Range</small></div><div><span className="event-dot muted" /><strong>AAPL 조건 미충족</strong><small>10:13:00 ET · 최초 실패 RSI</small></div></div></Panel></div>
  </div></Localized>;
}

export function BacktestView() {
  const columns = [{ key: 'time', label: '시각 (ET)' }, { key: 'symbol', label: '종목' }, { key: 'side', label: '행동', render: (r) => <span className={r.side === '매수' ? 'buy-text' : 'sell-text'}>{r.side}</span> }, { key: 'order', label: '요청액' }, { key: 'fill', label: '체결액' }, { key: 'fee', label: '수수료' }, { key: 'result', label: '결과' }];
  return <Localized><div className="page"><PageHeading eyebrow="AUTOMATED REVIEW" title="자동 백테스트" description="출시된 전략을 같은 분기의 고정 구간과 공식 데이터 스냅샷으로 평가합니다." meta={<Status tone="positive">완료 · 2026 Q3</Status>} actions={<Button icon={CalendarDays}>2026년 7월</Button>} />
    <div className="stats-grid four"><StatCard label="기간 수익률" value="+3.58%" detail="초기 $10,000" icon={ArrowUpRight} /><StatCard label="최대 낙폭" value="−2.14%" detail="기간 내 고점 대비" icon={Activity} /><StatCard label="개별 체결" value="42" detail="부분 체결 각각 집계" icon={CheckCircle2} /><StatCard label="비용 모델" value="0.25%" detail="수수료 0.2 + 슬리피지 0.05" icon={Coins} /></div>
    <div className="content-grid backtest-grid"><Panel className="span-2" title="자산 곡선" subtitle="2023 Q3–2026 Q2 · 조정 가격 데이터"><div className="chart-summary"><strong>$10,358.00</strong><span className="positive">+$358.00</span></div><AreaChart values={equitySeries} label="백테스트 자산 곡선" /></Panel><Panel title="조건 미충족 요약" subtitle="최초 실패 조건별 월간 횟수"><BarList items={monthlyFailures} /><HelpNote>거래가 없었던 개별 평가 로그는 보존하거나 표시하지 않습니다.</HelpNote></Panel><Panel className="span-3" title="2026년 7월 거래 상세" subtitle="주문·개별 체결·취소·거절과 거래 후 상태"><DataTable columns={columns} rows={trades} rowKey="time" /></Panel></div>
  </div></Localized>;
}

const officialCompetitions = [
  { name: 'I2S Summer League', status: '진행 중', people: '184명', remaining: '12일 남음', accent: 'blue' },
  { name: 'Risk Control Cup', status: '모집 중', people: '96명', remaining: '3일 후 시작', accent: 'violet' },
  { name: 'ETF Sprint', status: '진행 중', people: '128명', remaining: '6일 남음', accent: 'teal' },
];

const competitionRooms = [
  { name: 'Momentum Lab', status: '진행 중', score: '복합 점수', people: 10, joined: 8, remaining: '12일' },
  { name: 'ETF Discipline', status: '모집 중', score: '최대 낙폭', people: 20, joined: 5, remaining: '3일' },
  { name: 'Quant Study 04', status: '모집 중', score: '수익률', people: 8, joined: 3, remaining: '6일' },
  { name: 'Low Volatility Club', status: '진행 중', score: '샤프 지수', people: 30, joined: 24, remaining: '8일' },
];

export function RoomsView() {
  const [query, setQuery] = useState('');
  const [scoreFilter, setScoreFilter] = useState('all');
  const [sizeFilter, setSizeFilter] = useState('all');
  const [expanded, setExpanded] = useState(null);
  const visibleRooms = useMemo(() => competitionRooms.filter((room) => {
    const matchesQuery = room.name.toLowerCase().includes(query.trim().toLowerCase());
    const matchesScore = scoreFilter === 'all' || room.score === scoreFilter;
    const matchesSize = sizeFilter === 'all' || (sizeFilter === 'small' ? room.people <= 10 : room.people > 10);
    return matchesQuery && matchesScore && matchesSize;
  }), [query, scoreFilter, sizeFilter]);

  return <Localized><div className="page competition-page">
    <PageHeading eyebrow="BOT COMPETITION" title="Competition" description="같은 규칙 안에서 봇의 결과를 비교하고 참여할 Competition을 찾으세요." />

    <section className="official-competitions" aria-labelledby="official-title">
      <header><div><h2 id="official-title">공식 Competition</h2><span>운영팀이 관리하는 대회</span></div><span>{officialCompetitions.length}</span></header>
      <div>{officialCompetitions.map((competition, index) => <article className={`official-competition-card tone-${competition.accent}`} key={competition.name}>
        <div className="competition-card-top"><span><Trophy size={14} /> OFFICIAL</span><Status tone={competition.status === '진행 중' ? 'positive' : 'neutral'}>{competition.status}</Status></div>
        <h3>{competition.name}</h3>
        <div className="official-meta"><span><Users size={14} />{competition.people}</span><span><Clock3 size={14} />{competition.remaining}</span></div>
        <button>{index === 1 ? '참가 준비' : '현황 보기'}<ArrowUpRight size={15} /></button>
      </article>)}</div>
    </section>

    <section className="competition-browser panel">
      <header className="competition-browser-head"><div><h2>Competition 찾기</h2><span>{visibleRooms.length}개</span></div><Button kind="primary" icon={Plus}>Competition 만들기</Button></header>
      <div className="competition-toolbar">
        <label><Search size={15} /><input type="search" aria-label="Competition 검색" placeholder="이름으로 검색" value={query} onChange={(event) => setQuery(event.target.value)} /></label>
        <select aria-label="점수 방식 필터" value={scoreFilter} onChange={(event) => setScoreFilter(event.target.value)}>
          <option value="all">모든 점수 방식</option><option value="복합 점수">복합 점수</option><option value="최대 낙폭">최대 낙폭</option><option value="수익률">수익률</option><option value="샤프 지수">샤프 지수</option>
        </select>
        <select aria-label="참여 인원 필터" value={sizeFilter} onChange={(event) => setSizeFilter(event.target.value)}>
          <option value="all">모든 참여 인원</option><option value="small">10명 이하</option><option value="large">11명 이상</option>
        </select>
      </div>
      <div className="competition-list">
        {visibleRooms.map((room) => <article className={`competition-list-item ${expanded === room.name ? 'is-expanded' : ''}`} key={room.name}>
          <button className="competition-row-main" aria-label={`${room.name} 순위 펼치기`} aria-expanded={expanded === room.name} onClick={() => setExpanded((current) => current === room.name ? null : room.name)}>
            <span className="competition-emblem"><Medal size={17} /></span>
            <span className="competition-name"><strong>{room.name}</strong><small>{room.status} · {room.remaining} 남음</small></span>
            <span><small>점수 방식</small><strong>{room.score}</strong></span>
            <span><small>참여</small><strong>{room.joined} / {room.people}</strong></span>
            {expanded === room.name ? <ChevronUp size={17} /> : <ChevronDown size={17} />}
          </button>
          {expanded === room.name && <div className="competition-ranking" aria-label={`${room.name} 봇 순위`}>
            <header><span>순위</span><span>봇</span><span>점수</span><span>수익률</span></header>
            {leaderboard.map((entry) => <div className={entry.mine ? 'is-mine' : ''} key={entry.rank}><strong>#{entry.rank}</strong><span>{entry.bot}{entry.mine && <small>내 봇</small>}</span><b>{entry.score}</b><span className="positive">{entry.return}</span></div>)}
          </div>}
        </article>)}
        {visibleRooms.length === 0 && <div className="competition-empty"><Search size={20} /><strong>조건에 맞는 Competition이 없습니다.</strong><button onClick={() => { setQuery(''); setScoreFilter('all'); setSizeFilter('all'); }}>필터 초기화</button></div>}
      </div>
    </section>
  </div></Localized>;
}
