-- Tiny Hut: 3x3x3, smallest possible shelter
-- Inspired by Minecraft village small hut
return {
    name = "Tiny Hut",
    w = 3, d = 3, h = 3,
    doorPos = {x=1, y=0, z=0},
    tags = {"cozy", "tiny", "starter"},
    blocks = {
        -- Floor y=0: walls on perimeter
        {x=0,y=0,z=0,slot="primary"},{x=2,y=0,z=0,slot="primary"},
        {x=0,y=0,z=1,slot="primary"},{x=2,y=0,z=1,slot="primary"},
        {x=0,y=0,z=2,slot="primary"},{x=1,y=0,z=2,slot="primary"},{x=2,y=0,z=2,slot="primary"},
        -- Wall y=1
        {x=0,y=1,z=0,slot="primary"},{x=2,y=1,z=0,slot="primary"},
        {x=0,y=1,z=1,slot="secondary"},{x=2,y=1,z=1,slot="secondary"}, -- windows
        {x=0,y=1,z=2,slot="primary"},{x=1,y=1,z=2,slot="primary"},{x=2,y=1,z=2,slot="primary"},
        -- Roof y=2
        {x=0,y=2,z=0,slot="primary"},{x=1,y=2,z=0,slot="primary"},{x=2,y=2,z=0,slot="primary"},
        {x=0,y=2,z=1,slot="primary"},{x=1,y=2,z=1,slot="primary"},{x=2,y=2,z=1,slot="primary"},
        {x=0,y=2,z=2,slot="primary"},{x=1,y=2,z=2,slot="primary"},{x=2,y=2,z=2,slot="primary"},
    }
}
