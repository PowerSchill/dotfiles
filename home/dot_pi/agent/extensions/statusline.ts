/**
 * claude-statusline.ts — a Claude Code-style footer for the pi coding agent.
 *
 * Install: drop this file in ~/.pi/agent/extensions/ (global) or .pi/extensions/
 * (project-local), then run /reload or restart pi. Toggle with /statusline.
 *
 * Four rows, mirroring the Claude Code statusline:
 *
 *   ~/dev/project (main) • session-name
 *   opus-4-6 │ high │ [████████░░░░░░] 84.2k/200k (42%) │ In: 12.4k │ Cached: 71.8k │ Out: 4.1k
 *   Session: [███░░░░░░░] 12.0% │ 3h48m │ Weekly: [█░░░░░░░░░] 4.2% │ 5d02h11m │ $1.84 │ 1h12m
 *   ‖ plan mode on
 *
 * Row 3 caveat: pi has no equivalent of Claude Code's subscription rate-limit
 * windows, so those bars track spend against budgets you set below over rolling
 * 5h / 7d windows, persisted to ~/.pi/agent/statusline-usage.json. Under
 * subscription auth (/login) pi reports $0 per turn — set metric to "tokens"
 * (or PI_STATUSLINE_METRIC=tokens) to fill the bars from output tokens instead.
 */

import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type {
	ExtensionAPI,
	ExtensionContext,
	ReadonlyFooterDataProvider,
	Theme,
} from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { truncateToWidth } from "@earendil-works/pi-tui";

// ── Config ────────────────────────────────────────────────────────────────────

const CONFIG = {
	/** Show the custom footer at startup (otherwise toggle it with /statusline). */
	enabledByDefault: true,
	/** "cost" fills the budget bars from dollars, "tokens" from output tokens. */
	metric: (process.env.PI_STATUSLINE_METRIC === "tokens" ? "tokens" : "cost") as "cost" | "tokens",
	/** Rolling budget windows, matching Claude Code's 5h / 7d cadence. */
	sessionWindowHours: 5,
	weeklyWindowDays: 7,
	/** Budgets in dollars (metric "cost") or output tokens (metric "tokens"). */
	sessionBudget: Number(process.env.PI_SESSION_BUDGET ?? 15),
	weeklyBudget: Number(process.env.PI_WEEKLY_BUDGET ?? 150),
	/** Bar widths, in columns. */
	contextBarWidth: 14,
	budgetBarWidth: 10,
	/** Repaint interval so the countdowns tick while pi is idle. */
	refreshMs: 15_000,
	/** Rows degrade gracefully below these terminal widths. */
	minWidthForBudgets: 88,
	minWidthForTokens: 64,
};

/** Catppuccin Mocha. Swap the hex values for Latte / Frappé / Macchiato. */
const C = {
	text: "#cdd6f4",
	subtext: "#a6adc8",
	overlay: "#6c7086",
	surface: "#45475a",
	mauve: "#cba6f7",
	blue: "#89b4fa",
	sapphire: "#74c7ec",
	teal: "#94e2d5",
	green: "#a6e3a1",
	yellow: "#f9e2af",
	peach: "#fab387",
	red: "#f38ba8",
	pink: "#f5c2e7",
};

const THINKING_COLOR: Record<string, string> = {
	off: C.overlay,
	minimal: C.teal,
	low: C.green,
	medium: C.yellow,
	high: C.peach,
	xhigh: C.red,
	max: C.pink,
};

// ── ANSI helpers ──────────────────────────────────────────────────────────────

const RESET = "\x1b[0m";

function rgb(hex: string): string {
	const n = Number.parseInt(hex.slice(1), 16);
	return `\x1b[38;2;${(n >> 16) & 255};${(n >> 8) & 255};${n & 255}m`;
}

function fg(hex: string, text: string): string {
	return `${rgb(hex)}${text}${RESET}`;
}

function bold(hex: string, text: string): string {
	return `\x1b[1m${rgb(hex)}${text}${RESET}`;
}

/** Colour ramp: calm until 40%, warm through 90%, hot above. */
function heat(pct: number): string {
	if (pct >= 90) return C.red;
	if (pct >= 70) return C.peach;
	if (pct >= 40) return C.yellow;
	return C.green;
}

function bar(pct: number | null, width: number): string {
	if (pct === null) return fg(C.surface, `[${"·".repeat(width)}]`);
	const clamped = Math.max(0, Math.min(100, pct));
	const filled = Math.round((clamped / 100) * width);
	return (
		fg(C.surface, "[") +
		fg(heat(clamped), "█".repeat(filled)) +
		fg(C.surface, "░".repeat(width - filled)) +
		fg(C.surface, "]")
	);
}

function tokens(n: number): string {
	if (n < 1000) return `${n}`;
	if (n < 10_000) return `${(n / 1000).toFixed(1)}k`;
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
	return `${(n / 1_000_000).toFixed(1)}M`;
}

/** 2d18h12m / 1h12m / 12m — the format Claude Code uses for window countdowns. */
function duration(ms: number): string {
	if (ms <= 0) return "0m";
	const totalMinutes = Math.floor(ms / 60_000);
	const days = Math.floor(totalMinutes / 1440);
	const hours = Math.floor((totalMinutes % 1440) / 60);
	const minutes = totalMinutes % 60;
	if (days > 0) return `${days}d${String(hours).padStart(2, "0")}h${String(minutes).padStart(2, "0")}m`;
	if (hours > 0) return `${hours}h${String(minutes).padStart(2, "0")}m`;
	return `${minutes}m`;
}

// ── Rolling spend ledger ──────────────────────────────────────────────────────

interface SpendWindow {
	start: number;
	spend: number;
}
interface Ledger {
	session: SpendWindow;
	weekly: SpendWindow;
}

const LEDGER_PATH = join(process.env.PI_CONFIG_DIR ?? join(homedir(), ".pi", "agent"), "statusline-usage.json");
const SESSION_MS = CONFIG.sessionWindowHours * 3_600_000;
const WEEK_MS = CONFIG.weeklyWindowDays * 86_400_000;

function emptyLedger(now: number): Ledger {
	return { session: { start: now, spend: 0 }, weekly: { start: now, spend: 0 } };
}

function loadLedger(): Ledger {
	try {
		if (!existsSync(LEDGER_PATH)) return emptyLedger(Date.now());
		const parsed = JSON.parse(readFileSync(LEDGER_PATH, "utf8")) as Partial<Ledger>;
		const fallback = emptyLedger(Date.now());
		return { session: parsed.session ?? fallback.session, weekly: parsed.weekly ?? fallback.weekly };
	} catch {
		return emptyLedger(Date.now());
	}
}

let ledger = loadLedger();

/** Reset a window once it has aged out. Called before every read and write. */
function rollWindows(now = Date.now()): Ledger {
	if (now - ledger.session.start >= SESSION_MS) ledger.session = { start: now, spend: 0 };
	if (now - ledger.weekly.start >= WEEK_MS) ledger.weekly = { start: now, spend: 0 };
	return ledger;
}

function saveLedger(): void {
	try {
		mkdirSync(dirname(LEDGER_PATH), { recursive: true });
		const tmp = `${LEDGER_PATH}.${process.pid}.tmp`;
		writeFileSync(tmp, JSON.stringify(ledger), "utf8");
		renameSync(tmp, LEDGER_PATH);
	} catch {
		// A statusline should never take the agent down over a failed write.
	}
}

function recordSpend(amount: number): void {
	if (!Number.isFinite(amount) || amount <= 0) return;
	rollWindows();
	ledger.session.spend += amount;
	ledger.weekly.spend += amount;
	saveLedger();
}

// ── Extension ─────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	let tui: TUI | undefined;
	let enabled = false;
	const startedAt = Date.now();

	const repaint = () => tui?.requestRender();

	const makeFooter =
		(ctx: ExtensionContext) =>
		(hostTui: TUI, _theme: Theme, footerData: ReadonlyFooterDataProvider): Component & { dispose?(): void } => {
			tui = hostTui;
			const unsubscribe = footerData.onBranchChange(repaint);
			const ticker = setInterval(repaint, CONFIG.refreshMs);

			return {
				dispose() {
					clearInterval(ticker);
					unsubscribe();
					tui = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const rows: string[] = [];
					const sep = fg(C.surface, " │ ");

					// Row 1 — working directory, branch, session name.
					const home = process.env.HOME ?? homedir();
					const cwd = ctx.sessionManager.getCwd();
					let line = fg(C.blue, cwd.startsWith(home) ? `~${cwd.slice(home.length)}` : cwd);
					const branch = footerData.getGitBranch();
					if (branch) line += `${fg(C.overlay, " (")}${fg(C.mauve, branch)}${fg(C.overlay, ")")}`;
					const name = ctx.sessionManager.getSessionName();
					if (name) line += fg(C.overlay, " • ") + fg(C.subtext, name);
					rows.push(truncateToWidth(line, width));

					// Cumulative token usage across every assistant message in the session.
					let input = 0;
					let cached = 0;
					let output = 0;
					let cost = 0;
					for (const entry of ctx.sessionManager.getEntries()) {
						if (entry.type !== "message" || entry.message.role !== "assistant") continue;
						const usage = (entry.message as AssistantMessage).usage;
						input += usage.input;
						cached += usage.cacheRead + usage.cacheWrite;
						output += usage.output;
						cost += usage.cost.total;
					}

					// Row 2 — model, thinking level, context bar, token counts.
					const context = ctx.getContextUsage();
					const window = context?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const used = context?.tokens ?? null;
					const pct = context?.percent ?? null;

					const parts: string[] = [bold(C.mauve, ctx.model?.id ?? "no model")];
					if (ctx.model?.reasoning) {
						const level = ctx.thinkingLevel ?? pi.getThinkingLevel();
						parts.push(bold(THINKING_COLOR[level] ?? C.subtext, level));
					}
					parts.push(
						[
							bar(pct, CONFIG.contextBarWidth),
							fg(pct === null ? C.subtext : heat(pct), `${used === null ? "?" : tokens(used)}/${tokens(window)}`),
							fg(C.overlay, `(${pct === null ? "?" : pct.toFixed(0)}%)`),
						].join(" "),
					);
					if (width >= CONFIG.minWidthForTokens) {
						parts.push(
							`${fg(C.sapphire, "In:")} ${fg(C.text, tokens(input))}`,
							`${fg(C.sapphire, "Cached:")} ${fg(C.text, tokens(cached))}`,
							`${fg(C.sapphire, "Out:")} ${fg(C.text, tokens(output))}`,
						);
					}
					rows.push(truncateToWidth(parts.join(sep), width));

					// Row 3 — rolling budget windows, spend, wall-clock session length.
					if (width >= CONFIG.minWidthForBudgets) {
						const now = Date.now();
						const { session, weekly } = rollWindows(now);
						const sessionPct = CONFIG.sessionBudget > 0 ? (session.spend / CONFIG.sessionBudget) * 100 : 0;
						const weeklyPct = CONFIG.weeklyBudget > 0 ? (weekly.spend / CONFIG.weeklyBudget) * 100 : 0;
						rows.push(
							truncateToWidth(
								[
									`${fg(C.teal, "Session:")} ${bar(sessionPct, CONFIG.budgetBarWidth)} ${fg(heat(sessionPct), `${sessionPct.toFixed(1)}%`)}`,
									fg(C.subtext, duration(session.start + SESSION_MS - now)),
									`${fg(C.pink, "Weekly:")} ${bar(weeklyPct, CONFIG.budgetBarWidth)} ${fg(heat(weeklyPct), `${weeklyPct.toFixed(1)}%`)}`,
									fg(C.subtext, duration(weekly.start + WEEK_MS - now)),
									fg(C.green, CONFIG.metric === "cost" ? `$${cost.toFixed(2)}` : `${tokens(output)} out`),
									fg(C.overlay, duration(now - startedAt)),
								].join(sep),
								width,
							),
						);
					}

					// Row 4 — statuses published by other extensions via ctx.ui.setStatus().
					const statuses = [...footerData.getExtensionStatuses().values()]
						.map((s) => s.replace(/[\r\n\t]+/g, " ").trim())
						.filter(Boolean);
					if (statuses.length > 0) {
						rows.push(truncateToWidth(fg(C.overlay, statuses.join("  ·  ")), width));
					}

					return rows;
				},
			};
		};

	function apply(ctx: ExtensionContext, on: boolean): void {
		enabled = on;
		ctx.ui.setFooter(on ? makeFooter(ctx) : undefined);
	}

	pi.on("session_start", async (_event, ctx) => {
		if (CONFIG.enabledByDefault) apply(ctx, true);
	});

	// Keep the footer live: repaint whenever its inputs change.
	pi.on("message_update", async () => repaint());
	pi.on("turn_end", async () => repaint());
	pi.on("agent_end", async () => repaint());
	pi.on("model_select", async () => repaint());
	pi.on("thinking_level_select", async () => repaint());

	// Bank spend as each assistant message lands.
	pi.on("message_end", async (event) => {
		if (event.message.role !== "assistant") return;
		const usage = (event.message as AssistantMessage).usage;
		recordSpend(CONFIG.metric === "cost" ? usage.cost.total : usage.output);
		repaint();
	});

	pi.registerCommand("statusline", {
		description: "Toggle the Claude Code-style statusline",
		handler: async (_args, ctx) => {
			apply(ctx, !enabled);
			ctx.ui.notify(enabled ? "Statusline enabled" : "Default footer restored", "info");
		},
	});

	pi.registerCommand("statusline-reset", {
		description: "Reset the rolling session and weekly budget windows",
		handler: async (_args, ctx) => {
			ledger = emptyLedger(Date.now());
			saveLedger();
			repaint();
			ctx.ui.notify("Budget windows reset", "info");
		},
	});
}
