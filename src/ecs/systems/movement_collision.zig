const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

pub fn groupBy(world: ?*flecs.EcsWorld, table: ?*flecs.EcsTable, id: flecs.EcsId, ctx: ?*anyopaque) callconv(.C) flecs.EcsId {
    _ = ctx;
    var match: flecs.EcsId = 0;
    if (flecs.ecs_search(world, table, flecs.ecs_pair(id, flecs.Constants.EcsWildcard), &match) != -1) {
        return flecs.ecs_pair_second(match);
    }
    return 0;
}

pub fn system(world: *flecs.EcsWorld) flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Request, components.Movement) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Collider), .oper = flecs.EcsOperKind.ecs_optional });
    desc.run = run;

    var ctx_desc = std.mem.zeroes(flecs.EcsQueryDesc);
    ctx_desc.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Cell, flecs.Constants.EcsWildcard) });
    ctx_desc.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Tile) });
    ctx_desc.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.Collider) });
    ctx_desc.group_by = groupBy;
    ctx_desc.group_by_id = flecs.ecs_id(components.Cell);
    desc.ctx = flecs.ecs_query_init(world, &ctx_desc);

    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];

            if (flecs.ecs_field(it, components.Movement, 1)) |movements| {
                const target_tile = movements[i].end;
                const target_cell = target_tile.toCell();

                if (it.ctx) |ctx| {
                    var query = @ptrCast(*flecs.EcsQuery, ctx);
                    var query_it = flecs.ecs_query_iter(world, query);
                    if (game.state.cells.get(target_cell)) |cell_entity| {
                        flecs.ecs_query_set_group(&query_it, cell_entity);
                    }
                    while (flecs.ecs_iter_next(&query_it)) {
                        var j: usize = 0;
                        while (j < query_it.count) : (j += 1) {
                            if (flecs.ecs_field(&query_it, components.Tile, 2)) |target_tiles| {
                                if (query_it.entities[j] != entity) {
                                    if (target_tiles[j].x == target_tile.x and target_tiles[j].y == target_tile.y and target_tiles[j].z == target_tile.z) {
                                        // Collision. Set movement request to same tile to prevent extra frames on set/add and
                                        // zero movement direction and remove cooldown.
                                        movements[i].end = movements[i].start;
                                        flecs.ecs_set_pair(world, entity, &components.Direction{}, components.Movement);
                                        flecs.ecs_remove_pair(world, entity, components.Cooldown, components.Movement);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}