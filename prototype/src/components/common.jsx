import { ArrowUpRight, ChevronRight, CircleHelp, Search, SlidersHorizontal } from 'lucide-react';
import { Localized } from '../lib/i18n.jsx';

export function PageHeading({ eyebrow, title, description, actions, meta }) {
  return (
    <header className="page-heading">
      <div>
        {eyebrow && <p className="eyebrow">{eyebrow}</p>}
        <h1>{title}</h1>
        {description && <p className="page-description">{description}</p>}
      </div>
      <div className="page-actions">{meta && <span className="heading-meta">{meta}</span>}{actions}</div>
    </header>
  );
}

export function Status({ children, tone = 'neutral' }) {
  return <span className={`status status-${tone}`}><span className="status-dot" />{children}</span>;
}

export function StatCard({ label, value, detail, trend, icon: Icon }) {
  return (
    <article className="stat-card panel">
      <div className="stat-card-top"><span>{label}</span>{Icon && <Icon size={16} aria-hidden="true" />}</div>
      <strong>{value}</strong>
      <div className="stat-card-bottom">
        {trend && <span className={trend.startsWith('+') ? 'positive' : trend.startsWith('-') ? 'negative' : ''}>{trend}</span>}
        <span>{detail}</span>
      </div>
    </article>
  );
}

export function Panel({ title, subtitle, action, className = '', children }) {
  return (
    <section className={`panel ${className}`}>
      {(title || action) && <header className="panel-heading"><div><h2>{title}</h2>{subtitle && <p>{subtitle}</p>}</div>{action}</header>}
      {children}
    </section>
  );
}

export function Button({ children, kind = 'secondary', icon: Icon, className = '', ...props }) {
  return <button className={`button button-${kind} ${className}`} {...props}>{Icon && <Icon size={16} aria-hidden="true" />}{children}</button>;
}

export function SearchBar({ placeholder = '검색' }) {
  return <label className="search-box"><Search size={16} aria-hidden="true" /><input aria-label={placeholder} placeholder={placeholder} /><kbd>⌘K</kbd></label>;
}

export function FilterButton() {
  return <Button icon={SlidersHorizontal}>필터</Button>;
}

export function DataTable({ columns, rows, rowKey = 'name', className = '' }) {
  return (
    <Localized><div className={`table-wrap ${className}`}>
      <table>
        <thead><tr>{columns.map((column) => <th key={column.key}>{column.label}</th>)}</tr></thead>
        <tbody>{rows.map((row, index) => <tr key={row[rowKey] ?? index} className={row.mine ? 'is-mine' : ''}>{columns.map((column) => <td key={column.key}>{column.render ? column.render(row) : row[column.key]}</td>)}</tr>)}</tbody>
      </table>
    </div></Localized>
  );
}

export function InlineLink({ children }) {
  return <button className="inline-link">{children}<ArrowUpRight size={14} aria-hidden="true" /></button>;
}

export function HelpNote({ children }) {
  return <div className="help-note"><CircleHelp size={16} aria-hidden="true" /><span>{children}</span></div>;
}

export function ListRow({ icon: Icon, title, detail, end, active = false, onClick }) {
  const Tag = onClick ? 'button' : 'div';
  return <Tag className={`list-row ${active ? 'is-active' : ''}`} onClick={onClick}>{Icon && <span className="list-row-icon"><Icon size={17} /></span>}<span className="list-row-copy"><strong>{title}</strong><small>{detail}</small></span>{end ?? <ChevronRight size={16} className="muted" />}</Tag>;
}

export function Segmented({ value, onChange, items, label }) {
  return <div className="segmented" aria-label={label}>{items.map((item) => <button key={item.id} className={value === item.id ? 'active' : ''} onClick={() => onChange(item.id)}>{item.label}</button>)}</div>;
}
