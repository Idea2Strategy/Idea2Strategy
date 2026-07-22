import { fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, test } from 'vitest';
import { App } from './App.jsx';

describe('dual UI prototypes', () => {
  test.each([['balanced', 'BALANCED / ATLAS'], ['terminal', 'TERMINAL / PULSE']])('renders the %s variant with the shared product areas', (variant, label) => {
    render(<App initialVariant={variant} />);
    expect(screen.getByText(label)).toBeInTheDocument();
    for (const name of ['전략', '봇', '백테스트', '방', '알림']) expect(screen.getByRole('button', { name })).toBeInTheDocument();
  });

  test('switches variant and theme without losing the active page', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);
    await user.click(screen.getByRole('button', { name: '봇' }));
    await user.click(screen.getByRole('button', { name: '터미널형 보기' }));
    await user.click(screen.getByRole('button', { name: '다크 모드' }));
    expect(screen.getByText('TERMINAL / PULSE')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: '봇 운영 센터' })).toBeInTheDocument();
    expect(screen.getByTestId('app-shell')).toHaveAttribute('data-theme', 'dark');
  });

  test('shows rule-based fragments beside the Basic block group on review', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="balanced" />);
    await user.click(screen.getByRole('button', { name: 'Basic 편집기' }));
    const group = screen.getByTestId('basic-buy-group');
    expect(screen.queryByText('RSI가 입력한 기준 아래로 내려오면')).not.toBeInTheDocument();
    await user.hover(group);
    expect(screen.getByText('RSI가 입력한 기준 아래로 내려오면')).toBeInTheDocument();
    expect(screen.getByText('설정한 비율만큼 매수 후보를 만듭니다')).toBeInTheDocument();
  });

  test('opens a categorized compatible-node picker where a Pro connection is released', async () => {
    const user = userEvent.setup();
    render(<App initialVariant="terminal" />);
    await user.click(screen.getByRole('button', { name: 'Pro 편집기' }));
    fireEvent.pointerUp(screen.getByTestId('true-output'), { clientX: 438, clientY: 276 });
    const picker = screen.getByRole('dialog', { name: '호환 노드 선택' });
    expect(picker).toHaveStyle({ left: '438px', top: '276px' });
    expect(screen.getByText('조건 · 비교')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '포지션 확인' })).toBeEnabled();
  });
});
