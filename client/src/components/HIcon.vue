<template>
  <span class="hicon" :style="iconStyle" v-html="svgContent"></span>
</template>

<script setup>
import { ref, watch, computed } from 'vue'

const props = defineProps({
  name: { type: String, required: true },
  size: { type: [Number, String], default: 20 },
})

const svgContent = ref('')
const cache = new Map()

const iconStyle = computed(() => {
  const s = typeof props.size === 'number' ? `${props.size}px` : props.size
  return { width: s, height: s, fontSize: s }
})

const base = import.meta.env.BASE_URL || '/'

async function loadIcon(name) {
  if (cache.has(name)) {
    svgContent.value = cache.get(name)
    return
  }
  try {
    const res = await fetch(`${base}icons/${name}.svg`)
    if (!res.ok) { svgContent.value = ''; return }
    let svg = await res.text()
    svg = svg.replace(/width="24"/, `width="1em"`).replace(/height="24"/, `height="1em"`)
    cache.set(name, svg)
    svgContent.value = svg
  } catch {
    svgContent.value = ''
  }
}

watch(() => props.name, loadIcon, { immediate: true })
</script>

<style scoped>
.hicon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  line-height: 1;
  vertical-align: middle;
}

.hicon :deep(svg) {
  width: 1em;
  height: 1em;
  display: block;
}
</style>
