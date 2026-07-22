import { Activity, ArrowUpRight, Bot, CalendarDays, CheckCircle2, Clock3, Coins, Play, Plus, RefreshCw, Trophy, Users } from 'lucide-react';
import { AreaChart, BarList, MiniSpark } from '../components/charts.jsx';
import { Button, DataTable, HelpNote, PageHeading, Panel, StatCard, Status } from '../components/common.jsx';
import { bots, botSeries, equitySeries, leaderboard, monthlyFailures, positions, rooms, trades } from '../data/mockData.js';

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
  return <div className="page"><PageHeading eyebrow="LIVE OPERATIONS" title="봇 운영 센터" description="서버에서 실행 중인 봇과 공식 가상 체결 상태를 확인합니다." actions={<><Button icon={RefreshCw}>새로고침</Button><Button kind="primary" icon={Plus}>봇 출시</Button></>} />
    <div className="stats-grid four"><StatCard label="실행 중" value="2 / 10" detail="최대 동시 운영" icon={Play} /><StatCard label="전체 가상자산" value="$54,016.60" detail="3개 봇 합계" trend="+1.11%" icon={Coins} /><StatCard label="오늘 체결" value="07" detail="개별 체결 기준" icon={CheckCircle2} /><StatCard label="확인 기한" value="D−18" detail="Atlas 07 계속 실행" icon={Clock3} /></div>
    <div className="content-grid operations-grid"><Panel className="span-2" title="운영 자산" subtitle="Atlas 07 · 미국 동부 시각 기준" action={<span className="live-pill"><i /> MARKET OPEN</span>}><div className="chart-summary"><strong>$24,892.40</strong><span className="positive">+$450.18 · 1.84%</span></div><AreaChart values={botSeries} label="Atlas 07 자산 변화" /></Panel><Panel title="봇 상태" subtitle="실행·평가·조치 상태"><DataTable columns={botColumns} rows={bots} /></Panel><Panel className="span-2" title="현재 포지션" subtitle="공식 가상 체결 원장 기준"><DataTable columns={positionColumns} rows={positions} /></Panel><Panel title="최근 판단" subtitle="실시간 노드 실행은 표시하지 않습니다"><div className="event-list"><div><span className="event-dot positive" /><strong>SPY 주문 체결</strong><small>10:14:08 ET · 12주</small></div><div><span className="event-dot" /><strong>예산 상한 검사 통과</strong><small>10:14:02 ET · Opening Range</small></div><div><span className="event-dot muted" /><strong>AAPL 조건 미충족</strong><small>10:13:00 ET · 최초 실패 RSI</small></div></div></Panel></div>
  </div>;
}

export function BacktestView() {
  const columns = [{ key: 'time', label: '시각 (ET)' }, { key: 'symbol', label: '종목' }, { key: 'side', label: '행동', render: (r) => <span className={r.side === '매수' ? 'buy-text' : 'sell-text'}>{r.side}</span> }, { key: 'order', label: '요청액' }, { key: 'fill', label: '체결액' }, { key: 'fee', label: '수수료' }, { key: 'result', label: '결과' }];
  return <div className="page"><PageHeading eyebrow="AUTOMATED REVIEW" title="자동 백테스트" description="출시된 전략을 같은 분기의 고정 구간과 공식 데이터 스냅샷으로 평가합니다." meta={<Status tone="positive">완료 · 2026 Q3</Status>} actions={<Button icon={CalendarDays}>2026년 7월</Button>} />
    <div className="stats-grid four"><StatCard label="기간 수익률" value="+3.58%" detail="초기 $10,000" icon={ArrowUpRight} /><StatCard label="최대 낙폭" value="−2.14%" detail="기간 내 고점 대비" icon={Activity} /><StatCard label="개별 체결" value="42" detail="부분 체결 각각 집계" icon={CheckCircle2} /><StatCard label="비용 모델" value="0.25%" detail="수수료 0.2 + 슬리피지 0.05" icon={Coins} /></div>
    <div className="content-grid backtest-grid"><Panel className="span-2" title="자산 곡선" subtitle="2023 Q3–2026 Q2 · 조정 가격 데이터"><div className="chart-summary"><strong>$10,358.00</strong><span className="positive">+$358.00</span></div><AreaChart values={equitySeries} label="백테스트 자산 곡선" /></Panel><Panel title="조건 미충족 요약" subtitle="최초 실패 조건별 월간 횟수"><BarList items={monthlyFailures} /><HelpNote>거래가 없었던 개별 평가 로그는 보존하거나 표시하지 않습니다.</HelpNote></Panel><Panel className="span-3" title="2026년 7월 거래 상세" subtitle="주문·개별 체결·취소·거절과 거래 후 상태"><DataTable columns={columns} rows={trades} rowKey="time" /></Panel></div>
  </div>;
}

export function RoomsView() {
  const columns = [{ key: 'rank', label: '순위', render: (r) => <strong>#{r.rank}</strong> }, { key: 'bot', label: '봇' }, { key: 'score', label: '점수' }, { key: 'return', label: '수익률', render: (r) => <span className="positive">{r.return}</span> }, { key: 'drawdown', label: '최대 낙폭' }];
  return <div className="page"><PageHeading eyebrow="COMPETITION ROOMS" title="방과 리더보드" description="사용자가 만든 봇끼리 같은 일정과 방의 점수 템플릿으로 비교합니다." actions={<Button kind="primary" icon={Plus}>방 만들기</Button>} />
    <div className="room-grid">{rooms.map((room, index) => <article className={`room-card panel ${index === 0 ? 'featured' : ''}`} key={room.name}><header><div><Status tone={room.phase === '평가 중' ? 'positive' : 'neutral'}>{room.phase}</Status><span>{room.privacy}</span></div><Trophy size={18} /></header><h2>{room.name}</h2><p>{room.score}</p><div className="room-meta"><span><Users size={15} />{room.bots}</span><span><Clock3 size={15} />{room.remaining}</span></div><Button kind={index === 0 ? 'primary' : 'secondary'}>방 보기</Button></article>)}</div>
    <Panel title="Momentum Lab 리더보드" subtitle="다른 사용자의 신원은 공개하지 않고 봇만 비교합니다" action={<span className="heading-meta">평가 종료까지 12일</span>}><DataTable columns={columns} rows={leaderboard} rowKey="rank" /></Panel>
  </div>;
}
