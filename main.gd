extends Node2D

const WORLD := Vector2(2600,1600)
const SPEED := 360.0
const BOT_SPEED := 135.0
const BULLET_SPEED := 900.0

var player = {"pos":Vector2(1300,800),"hp":100.0,"cd":0.0,"alive":true}
var bots:Array = []
var bullets:Array = []
var loot:Array = []
var rng = RandomNumberGenerator.new()
var zone_center = Vector2(1300,800)
var zone_radius = 700.0
var zone_target = 700.0
var zone_timer = 30.0
var kills = 0
var over = false
var move_touch = Vector2.ZERO
var fire_touch = false
var hud:Label
var msg:Label

func _ready():
    rng.randomize()
    for i in 14:
        bots.append({"pos":rand_pos(),"hp":60.0,"cd":rng.randf_range(.5,2.0),"alive":true})
    for i in 18:
        loot.append({"pos":rand_pos(),"taken":false})
    make_ui()
    queue_redraw()

func rand_pos():
    return Vector2(rng.randf_range(180,2420),rng.randf_range(160,1440))

func make_ui():
    hud=Label.new(); hud.position=Vector2(20,15); hud.add_theme_font_size_override("font_size",24); add_child(hud)
    msg=Label.new(); msg.position=Vector2(0,280); msg.size=Vector2(1280,150); msg.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; msg.add_theme_font_size_override("font_size",48); add_child(msg)
    var data=[["◀",Vector2(30,585),Vector2(-1,0)],["▶",Vector2(150,585),Vector2(1,0)],["▲",Vector2(90,525),Vector2(0,-1)],["▼",Vector2(90,645),Vector2(0,1)]]
    for d in data:
        var b=Button.new(); b.text=d[0]; b.position=d[1]; b.size=Vector2(90,65); add_child(b)
        b.button_down.connect(func(): move_touch=d[2])
        b.button_up.connect(func(): move_touch=Vector2.ZERO)
    var f=Button.new(); f.text="FIRE"; f.position=Vector2(1080,575); f.size=Vector2(150,105); add_child(f)
    f.button_down.connect(func(): fire_touch=true); f.button_up.connect(func(): fire_touch=false)

func _process(delta):
    if over:
        queue_redraw()
        return
    update_player(delta)
    update_bots(delta)
    update_bullets(delta)
    update_zone(delta)
    update_hud()
    queue_redraw()

func update_player(delta):
    var v=Input.get_vector("move_left","move_right","move_up","move_down")
    if move_touch.length()>0: v=move_touch
    player.pos+=v.normalized()*SPEED*delta
    player.pos.x=clamp(player.pos.x,30.0,WORLD.x-30.0)
    player.pos.y=clamp(player.pos.y,30.0,WORLD.y-30.0)
    player.cd=max(0.0,player.cd-delta)
    if (Input.is_action_pressed("shoot") or fire_touch) and player.cd<=0:
        var target=get_global_mouse_position()
        fire(player.pos,(target-player.pos).normalized(),true)
        player.cd=.16
    if player.pos.distance_to(zone_center)>zone_radius: player.hp-=9*delta
    for p in loot:
        if not p.taken and player.pos.distance_to(p.pos)<40:
            p.taken=true; player.hp=min(100.0,player.hp+25)
    if player.hp<=0:
        player.alive=false; over=true; msg.text="ELIMINATED\nPress R to restart"

func update_bots(delta):
    for b in bots:
        if not b.alive: continue
        var d=player.pos-b.pos
        if d.length()>170: b.pos+=d.normalized()*BOT_SPEED*delta
        else: b.pos+=Vector2(-d.y,d.x).normalized()*BOT_SPEED*.35*delta
        b.cd-=delta
        if d.length()<700 and b.cd<=0:
            fire(b.pos,d.normalized(),false); b.cd=rng.randf_range(1,2)
        if b.pos.distance_to(zone_center)>zone_radius: b.hp-=7*delta
        if b.hp<=0: b.alive=false

func fire(pos,dir,from_player):
    bullets.append({"pos":pos,"vel":dir*BULLET_SPEED,"player":from_player,"life":1.5})

func update_bullets(delta):
    for b in bullets:
        b.pos+=b.vel*delta; b.life-=delta
        if b.life<=0: continue
        if b.player:
            for bot in bots:
                if bot.alive and b.pos.distance_to(bot.pos)<28:
                    bot.hp-=30; b.life=0
                    if bot.hp<=0: kills+=1
                    break
        elif player.alive and b.pos.distance_to(player.pos)<26:
            player.hp-=12; b.life=0
    bullets=bullets.filter(func(b): return b.life>0)

func update_zone(delta):
    zone_timer-=delta
    if zone_timer<=0 and zone_radius>150:
        zone_target=max(150.0,zone_radius-130); zone_timer=25
    zone_radius=move_toward(zone_radius,zone_target,8*delta)

func update_hud():
    var alive=1
    for b in bots:
        if b.alive: alive+=1
    hud.text="SHIMEON BATTLE ROYALE   HP:%d   KILLS:%d   ALIVE:%d   ZONE:%d" % [max(0,int(player.hp)),kills,alive,int(zone_radius)]
    if alive==1 and player.alive:
        over=true; msg.text="VICTORY!\nLast survivor"

func _unhandled_input(e):
    if e is InputEventKey and e.pressed and e.keycode==KEY_R and over:
        get_tree().reload_current_scene()

func _draw():
    draw_rect(Rect2(Vector2.ZERO,WORLD),Color("#18251d"))
    for x in range(0,2600,100): draw_line(Vector2(x,0),Vector2(x,1600),Color(0.12,0.22,0.15),1)
    for y in range(0,1600,100): draw_line(Vector2(0,y),Vector2(2600,y),Color(0.12,0.22,0.15),1)
    draw_circle(zone_center,zone_radius,Color(0.2,0.55,1,0.10))
    draw_arc(zone_center,zone_radius,0,TAU,128,Color(0.3,0.75,1),8)
    for p in loot:
        if not p.taken: draw_circle(p.pos,14,Color("#ffd84a"))
    for b in bots:
        if b.alive: draw_circle(b.pos,24,Color("#e04b4b"))
    if player.alive: draw_circle(player.pos,28,Color("#48a8ff"))
    for b in bullets: draw_circle(b.pos,6,Color.WHITE)
