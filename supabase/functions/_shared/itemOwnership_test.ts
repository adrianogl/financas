import { assertEquals } from "jsr:@std/assert@1"
import { connectTokenBody, ownsItem } from "./itemOwnership.ts"
import type { PluggyItem } from "./pluggyTypes.ts"

Deno.test("ownsItem só aceita item do mesmo usuário", () => {
  assertEquals(ownsItem({ clientUserId: "u1" } as PluggyItem, "u1"), true)
  assertEquals(ownsItem({ clientUserId: "u2" } as PluggyItem, "u1"), false)
  assertEquals(ownsItem({ clientUserId: null } as PluggyItem, "u1"), false)
  assertEquals(ownsItem({} as PluggyItem, "u1"), false)
})

Deno.test("connectTokenBody amarra o usuário em options e, na reconexão, o item", () => {
  assertEquals(connectTokenBody("u1"), { options: { clientUserId: "u1" } })
  assertEquals(connectTokenBody("u1", "it"), { itemId: "it", options: { clientUserId: "u1" } })
})
