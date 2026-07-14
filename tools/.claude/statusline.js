#!/usr/bin/env node
// Claude Code status line: Ctx bar | model | cost | 5h-usage bar
// Reads the Status hook JSON on stdin and prints a single line.
const fs = require('node:fs');

function rgb(r, g, b) {
	return `\x1b[38;2;${r};${g};${b}m`;
}
const RESET = '\x1b[0m';
const SEP = `${rgb(110, 110, 120)} │ ${RESET}`;
const TEXT = rgb(180, 180, 185);
const LABEL = rgb(140, 140, 150);

function readStdin() {
	try {
		return JSON.parse(fs.readFileSync(0, 'utf8'));
	} catch {
		return {};
	}
}

// Visible (printed) width of a string: strips ANSI escapes and counts
// emoji / wide symbols as 2 columns.
function visibleWidth(s) {
	let w = 0;
	for (const ch of s.replace(/\x1b\[[0-9;]*m/g, '')) {
		const cp = ch.codePointAt(0);
		const wide = cp >= 0x1f000 || (cp >= 0x2600 && cp <= 0x27bf) || (cp >= 0x1100 && cp <= 0x115f);
		w += wide ? 2 : 1;
	}
	return w;
}

// Greedily pack parts onto lines that fit within `cols`, joined by `sep`.
function layout(parts, sep, cols) {
	const sepW = visibleWidth(sep);
	const lines = [];
	let cur = [];
	let curW = 0;
	for (const p of parts) {
		const pw = visibleWidth(p);
		if (cur.length && curW + sepW + pw > cols) {
			lines.push(cur.join(sep));
			cur = [p];
			curW = pw;
		} else {
			curW += cur.length ? sepW + pw : pw;
			cur.push(p);
		}
	}
	if (cur.length) lines.push(cur.join(sep));
	return lines.join('\n');
}

// Fallback: total context tokens of the most recent transcript request,
// used only when the payload lacks context_window (older Claude Code).
function contextPctFromTranscript(transcriptPath, limit) {
	if (!transcriptPath || !fs.existsSync(transcriptPath)) return 0;
	let lines;
	try {
		lines = fs.readFileSync(transcriptPath, 'utf8').trim().split('\n');
	} catch {
		return 0;
	}
	for (let i = lines.length - 1; i >= 0; i--) {
		try {
			const u = JSON.parse(lines[i])?.message?.usage;
			if (u) {
				const used =
					(u.input_tokens || 0) +
					(u.cache_creation_input_tokens || 0) +
					(u.cache_read_input_tokens || 0);
				return Math.round((used / limit) * 100);
			}
		} catch {
			// skip malformed lines
		}
	}
	return 0;
}

function color(pct) {
	// cyan (low) -> yellow (mid) -> red (high)
	return pct >= 90 ? rgb(235, 95, 80) : pct >= 70 ? rgb(235, 205, 70) : rgb(80, 200, 220);
}

// Compact countdown to a reset timestamp (epoch seconds): ↻45m / ↻3h / ↻2d
function resetIn(ts) {
	if (!ts) return '';
	const mins = Math.max(0, Math.round((ts * 1000 - Date.now()) / 60_000));
	const str = mins < 60 ? `${mins}m` : mins < 1440 ? `${Math.round(mins / 60)}h` : `${Math.round(mins / 1440)}d`;
	return `${LABEL} ↻ ${str}${RESET}`;
}

function bar(pct, label, width = 14) {
	const p = Math.min(100, Math.max(0, Math.round(pct)));
	const filled = Math.min(width, Math.round((p / 100) * width));
	const track = rgb(70, 74, 84);
	return `${LABEL}${label} ${color(p)}${'█'.repeat(filled)}${track}${'█'.repeat(width - filled)} ${color(p)}${p}%${RESET}`;
}

const data = readStdin();
const name = data?.model?.display_name || 'Claude';
const id = (data?.model?.id || '').toLowerCase();
const limit =
	data?.context_window?.context_window_size ||
	(/1m|\[1m\]/.test(`${name} ${id}`) || data?.exceeds_200k_tokens ? 1_000_000 : 200_000);

const ctxPct =
	typeof data?.context_window?.used_percentage === 'number'
		? data.context_window.used_percentage
		: contextPctFromTranscript(data?.transcript_path, limit);

const fiveHour = data?.rate_limits?.five_hour;
const sevenDay = data?.rate_limits?.seven_day;
const fiveHourUsagePct = fiveHour?.used_percentage;
const weeklyUsagePct = sevenDay?.used_percentage;
const hasFiveHourUsage = typeof fiveHourUsagePct === 'number';
const hasWeeklyUsage = typeof weeklyUsagePct === 'number';

const cost = typeof data?.cost?.total_cost_usd === 'number' ? data.cost.total_cost_usd : 0;

const fast = data?.fast_mode ? ' ⚡' : '';
const effort = data?.effort?.level ? `${LABEL} · ${data.effort.level} effort` : '';

const costStr =
	cost > 25
		? `\x1b[1m\x1b[48;2;200;60;50m\x1b[38;2;255;255;255m $${cost.toFixed(2)} ${RESET}`
		: `${TEXT}$${cost.toFixed(2)}${RESET}`;

// Keep cost and available usage bars together so they wrap as one group.
// Some Codex accounts expose only a weekly window, so absent windows must not
// be presented as 0% usage.
let usage = costStr;
if (hasFiveHourUsage) {
	usage += `${SEP}${bar(fiveHourUsagePct, '5H Usage:')}${resetIn(fiveHour?.resets_at)}`;
}
// Show weekly usage at all levels when it is the only available quota. When a
// five-hour window exists too, keep the prior behavior of surfacing it at 50%.
if (hasWeeklyUsage && (!hasFiveHourUsage || weeklyUsagePct >= 50)) {
	usage += `${SEP}${bar(weeklyUsagePct, 'Weekly Usage:')}${resetIn(sevenDay?.resets_at)}`;
}

const parts = [bar(ctxPct, 'Ctx:'), `${TEXT}${name}${effort}${fast}${RESET}`, usage];

const cols = (Number.parseInt(process.env.COLUMNS || '', 10) || Infinity) - 2;
process.stdout.write(layout(parts, SEP, cols));
