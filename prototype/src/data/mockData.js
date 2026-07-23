export const strategies = [
  { name: 'Opening Range Flow', mode: 'Basic', state: '검증 완료', updated: '07.23 09:41 ET', blocks: 7, backtest: '가능' },
  { name: 'Pair Spread Monitor', mode: 'Pro', state: '미완성', updated: '07.22 15:18 ET', blocks: 14, backtest: '가능' },
  { name: 'Volume Regime Draft', mode: 'Pro', state: '임시 저장', updated: '07.21 11:05 ET', blocks: 11, backtest: '데이터 확인' },
];

export const templates = [
  { type: '매수', name: 'RSI 하향 기준', detail: 'RSI · 하향 · 매수', fields: 3 },
  { type: '매도', name: '이동평균 하향 교차', detail: 'MA · 교차 · 매도', fields: 4 },
  { type: 'Pro', name: 'Pair spread structure', detail: '병렬 · 스프레드 · 균형', fields: 9 },
];

export const bots = [
  { name: 'Atlas 07', state: '실행 중', capital: '$24,892.40', change: '+1.84%', strategies: 2, room: '개인 봇' },
  { name: 'Room Beta', state: '평가 중', capital: '$10,184.12', change: '+1.84%', strategies: 1, room: 'Momentum Lab' },
  { name: 'Pair Lab', state: '조치 필요', capital: '$18,940.08', change: '-0.38%', strategies: 2, room: '개인 봇' },
];

export const positions = [
  { symbol: 'AAPL', qty: '18', avg: '$214.08', price: '$216.42', pnl: '+$42.12', share: '15.6%' },
  { symbol: 'MSFT', qty: '9', avg: '$492.30', price: '$497.18', pnl: '+$43.92', share: '18.0%' },
  { symbol: 'SPY', qty: '12', avg: '$632.14', price: '$634.06', pnl: '+$23.04', share: '30.6%' },
];

export const equitySeries = [10000, 10042, 10018, 10096, 10120, 10088, 10164, 10148, 10211, 10192, 10248, 10276, 10312, 10296, 10358];
export const botSeries = [24000, 24120, 24078, 24260, 24318, 24492, 24370, 24630, 24780, 24892];

export const trades = [
  { time: '07.18 10:14', symbol: 'SPY', side: '매수', order: '$1,480.20', fill: '$1,482.08', fee: '$2.96', result: '체결' },
  { time: '07.17 14:42', symbol: 'MSFT', side: '매도', order: '$2,965.44', fill: '$2,961.20', fee: '$5.92', result: '부분 체결' },
  { time: '07.15 09:48', symbol: 'AAPL', side: '매수', order: '$2,140.80', fill: '$2,143.12', fee: '$4.28', result: '체결' },
  { time: '07.11 11:03', symbol: 'QQQ', side: '매수', order: '$1,880.00', fill: '—', fee: '—', result: '거절' },
];

export const rooms = [
  { name: 'Momentum Lab', phase: '평가 중', bots: '8 / 10', remaining: '12일 04시간', score: '복합 점수 v2', privacy: '공개' },
  { name: 'ETF Discipline', phase: '제출 중', bots: '5 / 10', remaining: '3일 18시간', score: '최대 낙폭', privacy: '공개' },
  { name: 'Quant Study 04', phase: '모집 중', bots: '3 / 8', remaining: '6일 09시간', score: '수익률', privacy: '비밀' },
];

export const leaderboard = [
  { rank: 1, bot: 'Bot 3F9A', score: '82.41', return: '+4.18%', drawdown: '-1.08%', mine: false },
  { rank: 2, bot: 'Room Beta', score: '80.92', return: '+3.84%', drawdown: '-0.94%', mine: true },
  { rank: 3, bot: 'Bot 8C21', score: '78.07', return: '+3.58%', drawdown: '-1.44%', mine: false },
  { rank: 4, bot: 'Bot 11D0', score: '74.36', return: '+2.96%', drawdown: '-1.12%', mine: false },
];

export const notifications = [
  { kind: '조치 필요', title: 'Pair Lab 데이터 확인', detail: '새 주문 평가를 보류하고 기존 상태를 유지합니다.', time: '4분 전', unread: true },
  { kind: '체결', title: 'Atlas 07 · SPY 전량 체결', detail: '12주 · 평균 $634.06 · 수수료 $15.22', time: '18분 전', unread: true },
  { kind: '방', title: 'Momentum Lab 평가 12일 남음', detail: '평가 종료 시점에 공식 결과가 확정됩니다.', time: '1시간 전', unread: false },
  { kind: '백테스트', title: 'Opening Range Flow 완료', detail: '2023 Q3–2026 Q2 공식 구간 처리가 완료되었습니다.', time: '어제', unread: false },
];

export const monthlyFailures = [
  { label: '거래량 기준 미충족', value: 184 },
  { label: '포지션 보유 조건', value: 96 },
  { label: 'RSI 기준 미충족', value: 244 },
  { label: '예산 상한 도달', value: 31 },
];

export const ticker = [
  ['S&P 500', '6,377.82', '+0.41%'],
  ['NASDAQ', '21,028.14', '+0.63%'],
  ['VIX', '15.26', '-2.18%'],
  ['MARKET', 'OPEN', '03:42:18'],
];
