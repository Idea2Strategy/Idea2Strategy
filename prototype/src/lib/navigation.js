import { Bot, Building2, FlaskConical, LayoutGrid, ShieldCheck, Trophy } from 'lucide-react';

export const navItems = [
  { id: 'strategy', label: '전략', icon: LayoutGrid },
  { id: 'bots', label: '봇', icon: Bot },
  { id: 'backtest', label: '백테스트', icon: FlaskConical },
  { id: 'rooms', label: 'Competition', icon: Trophy },
];

export const utilityItems = [
  { id: 'account', label: '계정', icon: ShieldCheck },
  { id: 'admin', label: '관리자', icon: Building2 },
];

export function variantFromLocation(pathname = '') {
  return pathname.includes('terminal') ? 'terminal' : 'balanced';
}
