import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, test } from 'vitest';
import { BasicEditor } from './views/StrategyViews.jsx';

describe('Basic editor strategy explanations', () => {
  test('opens one natural-language explanation for the whole buy or sell group', async () => {
    const user = userEvent.setup();
    render(<BasicEditor goBack={() => {}} />);

    await user.hover(screen.getByTestId('buy-rsi-block'));
    expect(screen.queryByText(/새로운 1분봉/)).not.toBeInTheDocument();

    const buyExplanation = screen.getByRole('button', { name: '매수 전략 자연어 설명' });
    await user.click(buyExplanation);
    const buyTooltip = screen.getByRole('tooltip');
    expect(buyTooltip).toHaveTextContent('새로운 1분봉');
    expect(buyTooltip).toHaveTextContent('RSI가 30 아래');
    expect(buyTooltip).toHaveTextContent('25%');
    expect(buyExplanation).toHaveAttribute('aria-expanded', 'true');

    const sellExplanation = screen.getByRole('button', { name: '매도 전략 자연어 설명' });
    await user.click(sellExplanation);
    expect(screen.queryByText(/새로운 1분봉/)).not.toBeInTheDocument();
    expect(screen.getByRole('tooltip')).toHaveTextContent('포지션을 보유한 상태');
    expect(screen.getByRole('tooltip')).toHaveTextContent('RSI가 70 위');

    await user.click(sellExplanation);
    expect(screen.queryByText(/포지션을 보유한 상태/)).not.toBeInTheDocument();
  });

  test('keeps the final buy and sell outputs attached and non-interactive', () => {
    render(<BasicEditor goBack={() => {}} />);

    for (const testId of ['buy-order-block', 'sell-order-block']) {
      const output = screen.getByTestId(testId);
      expect(output).toHaveClass('fixed-terminal-block');
      expect(output).toHaveAttribute('aria-disabled', 'true');
      expect(output.closest('.strategy-container-footer')).not.toBeNull();
    }
  });
});
