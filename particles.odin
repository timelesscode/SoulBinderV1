package sb

import rl   "vendor:raylib"
import rand "core:math/rand"
import "core:fmt"
import "core:math"

// ---- color helpers ----

COL_DMG   :: [4]u8{220,  60,  60, 255}
COL_HEAL  :: [4]u8{ 60, 220, 100, 255}
COL_MP    :: [4]u8{ 60, 140, 255, 255}
COL_CRIT  :: [4]u8{255, 220,  40, 255}
COL_MISS  :: [4]u8{160, 160, 160, 255}

// ---- combat screen positions ----

combat_player_cx :: proc() -> f32 { return 60 + 72 }
combat_player_cy :: proc() -> f32 { return f32(sh()) - 240 + 72 }
combat_enemy_cx  :: proc() -> f32 { return f32(sw() - 240) }
combat_enemy_cy  :: proc() -> f32 { return f32(sh())/2 - 80 }

// ---- spawn helpers ----

spawn_burst :: proc(g: ^GameState, x, y: f32, col: [4]u8, count: int, speed: f32 = 120) {
	if len(g.particles) > 200 do return
	for _ in 0..<count {
		angle := rand.float32() * math.TAU
		spd   := rand.float32() * speed + speed * 0.3
		append(&g.particles, Particle{
			x = x, y = y,
			vx = math.cos(angle) * spd,
			vy = math.sin(angle) * spd - speed * 0.5,
			life = rand.float32() * 0.4 + 0.4,
			size = rand.float32() * 5 + 3,
			col  = col,
		})
	}
}

spawn_float :: proc(g: ^GameState, x, y: f32, text: string, col: [4]u8, sz: i32 = 22) {
	ft: FloatText
	ft.x   = x
	ft.y   = y
	ft.vy  = -90
	ft.life = 1.4
	ft.col  = col
	ft.sz   = sz
	n := min(len(text), 23)
	copy(ft.buf[:], text[:n])
	ft.blen = n
	append(&g.float_texts, ft)
}

// ---- public effect spawners ----

fx_damage_enemy :: proc(g: ^GameState, amount: int, crit: bool = false) {
	x := combat_enemy_cx()
	y := combat_enemy_cy() - 30
	col := crit ? COL_CRIT : COL_DMG
	spawn_burst(g, x, y, col, 12)
	spawn_float(g, x, y - 20, fmt.tprintf("-%d", amount), col, crit ? 28 : 22)
}

fx_damage_player :: proc(g: ^GameState, amount: int) {
	x := combat_player_cx()
	y := combat_player_cy() - 30
	spawn_burst(g, x, y, COL_DMG, 10)
	spawn_float(g, x, y - 20, fmt.tprintf("-%d", amount), COL_DMG)
}

fx_heal_player :: proc(g: ^GameState, amount: int) {
	x := combat_player_cx()
	y := combat_player_cy() - 40
	spawn_burst(g, x, y, COL_HEAL, 14, 80)
	spawn_float(g, x, y - 20, fmt.tprintf("+%d HP", amount), COL_HEAL, 20)
}

fx_mp_used :: proc(g: ^GameState) {
	x := combat_player_cx()
	y := combat_player_cy()
	spawn_burst(g, x, y, COL_MP, 8, 60)
}

fx_miss :: proc(g: ^GameState, on_enemy: bool) {
	x := on_enemy ? combat_enemy_cx() : combat_player_cx()
	y := on_enemy ? combat_enemy_cy() : combat_player_cy()
	spawn_float(g, x, y - 30, "MISS", COL_MISS, 20)
}

fx_weakness :: proc(g: ^GameState) {
	x := combat_enemy_cx()
	y := combat_enemy_cy() - 60
	col := [4]u8{255, 255, 60, 255}
	spawn_burst(g, x, y, col, 20, 160)
	spawn_float(g, x, y - 10, "WEAK!", col, 30)
}

fx_null :: proc(g: ^GameState) {
	x := combat_enemy_cx()
	y := combat_enemy_cy() - 40
	spawn_float(g, x, y, "NULL", COL_MISS, 24)
}

fx_absorb :: proc(g: ^GameState, amount: int) {
	x := combat_enemy_cx()
	y := combat_enemy_cy() - 40
	spawn_burst(g, x, y, COL_HEAL, 12)
	spawn_float(g, x, y - 10, fmt.tprintf("ABS +%d", amount), COL_HEAL, 20)
}

// ---- update ----

update_effects :: proc(g: ^GameState, dt: f32) {
	// particles
	i := 0
	for i < len(g.particles) {
		p := &g.particles[i]
		p.x    += p.vx * dt
		p.y    += p.vy * dt
		p.vy   += 240 * dt   // gravity
		p.life -= dt * 1.8
		if p.life <= 0 {
			ordered_remove(&g.particles, i)
		} else {
			i += 1
		}
	}

	// float texts
	j := 0
	for j < len(g.float_texts) {
		ft := &g.float_texts[j]
		ft.y    += ft.vy * dt
		ft.vy   *= 0.92        // decelerate
		ft.life -= dt
		if ft.life <= 0 {
			ordered_remove(&g.float_texts, j)
		} else {
			j += 1
		}
	}
}

// ---- draw ----

draw_effects :: proc(g: ^GameState) {
	for p in g.particles {
		alpha := u8(p.life * 255)
		col   := rl.Color{p.col[0], p.col[1], p.col[2], alpha}
		rl.DrawCircle(i32(p.x), i32(p.y), p.size * p.life, col)
	}

	for &ft in g.float_texts {
		alpha  := u8(min(ft.life / 0.4, 1.0) * 255)
		col    := rl.Color{ft.col[0], ft.col[1], ft.col[2], alpha}
		cs     := cstring(&ft.buf[0])
		tw     := rl.MeasureText(cs, ft.sz)
		rl.DrawText(cs, i32(ft.x) - tw/2, i32(ft.y), ft.sz, col)
		rl.DrawText(cs, i32(ft.x) - tw/2 + 1, i32(ft.y) + 1, ft.sz, {0,0,0, alpha/2})
	}
}
