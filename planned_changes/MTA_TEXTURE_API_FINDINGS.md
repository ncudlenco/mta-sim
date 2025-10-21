# MTA-Blue Texture API Implementation Research

## Executive Summary

This document details how MTA-Blue implements Lua texture APIs and tracks texture names at the DirectX level. The key finding is that **MTA does NOT have direct access to texture names from `IDirect3DTexture9` pointers**. Instead, MTA maintains its own **separate mapping system** that associates texture metadata with D3D texture pointers.

---

## Key Architecture Components

### 1. Texture Tracking System

**File**: `Client/game_sa/CRenderWareSA.h`

MTA maintains two critical data structures for texture tracking:

```cpp
class CRenderWareSA : public CRenderWare
{
    // Watched world textures
    std::multimap<ushort, STexInfo*>    m_TexInfoMap;           // TxdID -> Texture Info
    CFastHashMap<CD3DDUMMY*, STexInfo*> m_D3DDataTexInfoMap;    // D3D Texture -> Texture Info
    // ...
};
```

**Key Insight**: `CD3DDUMMY*` is MTA's typedef for tracking D3D texture pointers. MTA builds a **hash map** that maps these pointers to `STexInfo` structures containing texture metadata.

### 2. Texture Information Structure

**File**: `Client/game_sa/CRenderWareSA.ShaderSupport.h`

```cpp
struct STexInfo
{
    STexTag         texTag;              // Unique identifier
    SString         strTextureName;      // **THE TEXTURE NAME** stored separately
    CD3DDUMMY*      pD3DData;           // Pointer to IDirect3DTexture9
    // ... additional metadata
};
```

**Critical Detail**: The texture name (`strTextureName`) is stored in MTA's own data structure, NOT extracted from DirectX. DirectX textures themselves do not inherently store names.

---

## How Texture Names Are Tracked

### Step 1: Texture Stream-In Hook

When GTA streams in a texture, MTA intercepts this through hooks and calls:

```cpp
void CRenderWareSA::StreamingAddedTexture(ushort usTxdId, const SString& strTextureName, CD3DDUMMY* pD3DData)
{
    STexInfo* pTexInfo = CreateTexInfo(texTag, strTextureName, pD3DData);
    // Store in maps
    m_D3DDataTexInfoMap[pD3DData] = pTexInfo;
    m_TexInfoMap.insert(std::make_pair(usTxdId, pTexInfo));
}
```

**Source of Names**: Texture names come from:
- **RenderWare (RW) structures**: GTA uses RenderWare, which stores texture names in `RwTexture::name` (char array)
- **TXD file parsing**: When loading TXD files, MTA reads the RenderWare texture dictionary format

### Step 2: RenderWare Texture Structure

**File**: GTA's RenderWare structure (referenced in texture code)

```cpp
struct RwTexture
{
    char name[32];      // Texture name stored in RenderWare format
    char mask[32];      // Alpha mask name
    RwTexDictionary* txd;
    // ... other fields
};
```

MTA extracts names from these RenderWare structures BEFORE textures are converted to DirectX format.

---

## Implementation of Lua APIs

### 1. `engineGetVisibleTextureNames()`

**File**: `Client/core/Graphics/CRenderItemManager.TextureReplace.cpp`

**Implementation Flow**:

```cpp
void CRenderItemManager::GetVisibleTextureNames(std::vector<SString>& outNameList,
                                                  const SString& strTextureNameMatch,
                                                  ushort usModelID)
{
    // Iterate textures used in previous frame
    for (CD3DDUMMY* pD3DData : m_PrevFrameTextureUsage)
    {
        // Get name from MTA's tracking system (NOT from D3D texture)
        const char* szTextureName = m_pRenderWare->GetTextureName(pD3DData);

        // Filter by wildcard match
        if (WildcardMatchI(strTextureNameMatchLower, szTextureName))
            resultMap.insert(szTextureName);
    }
}
```

**Key Variables**:
- `m_FrameTextureUsage`: Hash set populated during rendering (current frame)
- `m_PrevFrameTextureUsage`: Previous frame's textures (for stability)

### 2. `engineApplyShaderToWorldTexture()`

**File**: `Client/core/Graphics/CRenderItemManager.TextureReplace.cpp`

**Implementation**:

```cpp
bool CRenderItemManager::ApplyShaderItemToWorldTexture(CShaderItem* pShaderItem,
                                                         const SString& strTextureNameMatch,
                                                         CClientEntityBase* pClientEntity,
                                                         bool bAppendLayers)
{
    // Register shader with pattern-matching system
    m_pRenderWare->AppendAdditiveMatch(
        pShaderItem,
        pClientEntity,
        strTextureNameMatch,  // Wildcard pattern
        priority,
        layered,
        typeMask
    );
}
```

**Shader Application Process**:
1. Shader registered with texture name pattern (wildcards supported)
2. During rendering, `GetAppliedShaderForD3DData()` checks if D3D texture matches pattern
3. Lookup performed using `m_D3DDataTexInfoMap` to get texture name
4. Pattern matching against registered shaders

### 3. `engineGetModelTextureNames()`

**File**: `Client/game_sa/CRenderWareSA.TextureReplacing.cpp`

**Implementation**:

```cpp
void CRenderWareSA::GetModelTextureNames(std::vector<SString>& outNameList, ushort usModelID)
{
    // Get TXD ID for model
    ushort usTxdId = GetTXDIDForModelID(usModelID);

    // Get TXD dictionary
    RwTexDictionary* pTxd = CTxdStore_GetTxd(usTxdId);

    // Enumerate textures in TXD
    std::vector<RwTexture*> textures;
    GetTxdTextures(textures, pTxd);

    // Extract names from RwTexture structures
    for (RwTexture* pTexture : textures)
    {
        outNameList.push_back(pTexture->name);  // Read from RW structure
    }
}
```

---

## Critical Data Flow

### Texture Name → D3D Texture Mapping

```
┌─────────────────────────────────────────────────────────────────┐
│                    GTA TEXTURE STREAMING                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
    ┌─────────────────────────────────────────────────┐
    │  RenderWare Texture (RwTexture)                 │
    │  - name: "wall_texture"  (char[32])             │
    │  - raster: RwRaster* (contains pixel data)      │
    └─────────────────────────────────────────────────┘
                              ↓
         ┌────────────────────────────────────┐
         │   MTA INTERCEPTS STREAMING         │
         │   StreamingAddedTexture() hook     │
         └────────────────────────────────────┘
                              ↓
    ┌──────────────────────────────────────────────────┐
    │  MTA Creates STexInfo                            │
    │  - strTextureName = "wall_texture" (copied)      │
    │  - pD3DData = IDirect3DTexture9*                 │
    └──────────────────────────────────────────────────┘
                              ↓
         ┌────────────────────────────────────────────┐
         │   STORED IN MTA's TRACKING MAPS            │
         │   m_D3DDataTexInfoMap[pD3DData] = pTexInfo │
         └────────────────────────────────────────────┘
                              ↓
    ┌───────────────────────────────────────────────────┐
    │   DirectX Texture (IDirect3DTexture9)             │
    │   - NO NAME FIELD                                 │
    │   - Only pixel data + metadata (format, size)     │
    └───────────────────────────────────────────────────┘
```

### Lookup Process (GetTextureName)

```
Lua: engineGetVisibleTextureNames()
         ↓
CRenderItemManager::GetVisibleTextureNames()
         ↓
For each CD3DDUMMY* in m_PrevFrameTextureUsage:
         ↓
m_pRenderWare->GetTextureName(pD3DData)
         ↓
Lookup in m_D3DDataTexInfoMap[pD3DData]
         ↓
Return pTexInfo->strTextureName
         ↓
Back to Lua as string
```

---

## Key Findings

### 1. No Direct D3D → Name Mapping

**IDirect3DTexture9 does NOT store texture names**. DirectX textures only contain:
- Pixel data (in D3D surfaces/levels)
- Format information (D3DFORMAT)
- Dimensions (width, height, mip levels)
- Usage flags
- Private driver data (opaque)

### 2. MTA's Solution: Shadow Tracking

MTA maintains a **parallel tracking system** that associates:
- `CD3DDUMMY*` (D3D texture pointer) → `STexInfo*` (metadata structure)
- `STexInfo` contains the texture name copied from RenderWare

### 3. Frame-Based Visibility Tracking

```cpp
// CRenderItemManager.h
CFastHashSet<CD3DDUMMY*> m_FrameTextureUsage;      // Current frame
CFastHashSet<CD3DDUMMY*> m_PrevFrameTextureUsage;  // Previous frame (stable)
```

**Process**:
1. During rendering, MTA hooks into texture setting calls
2. Each texture used is added to `m_FrameTextureUsage`
3. At frame end: `m_PrevFrameTextureUsage = m_FrameTextureUsage`
4. `engineGetVisibleTextureNames()` reads from `m_PrevFrameTextureUsage` (prevents mid-frame inconsistencies)

### 4. Texture Name Source: RenderWare

Texture names originate from:

**TXD Files** (GTA's texture archive format):
- Uses RenderWare binary format
- Contains `RwTexDictionary` structures
- Each `RwTexture` has a 32-byte name field
- MTA parses these during TXD loading:

```cpp
// From CRenderWareSA.TextureReplacing.cpp
RwTexDictionary* CRenderWareSA::ReadTXD(const SString& strFilename, const SString& buffer)
{
    // Parse RenderWare binary format
    RwTexDictionary* pTxd = RwTexDictionaryStreamRead(...);

    // Enumerate textures
    GetTxdTextures(textures, pTxd);

    // Names are in RwTexture::name
}
```

---

## Implications for Your Use Case

### Can You Get Texture Names from IDirect3DTexture9 Pointers?

**NO** - Not without MTA's tracking system. DirectX provides no standard way to retrieve texture names from texture pointers.

### Solutions:

#### Option 1: Hook Into MTA's System (Recommended)
If you're working within MTA's module system, you can:
1. Access `CRenderWareSA::m_D3DDataTexInfoMap`
2. Use `GetTextureName(CD3DDUMMY* pD3DData)` method
3. This requires module access to MTA's internal structures

#### Option 2: Build Your Own Tracking
Similar to MTA's approach:
1. Hook texture creation/loading points
2. Extract names from RenderWare structures BEFORE D3D conversion
3. Maintain your own `std::unordered_map<IDirect3DTexture9*, std::string>`
4. Hook texture destruction to clean up map

#### Option 3: Use SetPrivateData (Limited)
DirectX allows storing custom data:
```cpp
// At texture creation
pTexture->SetPrivateData(GUID_TextureName, nameLength, textureName, 0);

// Later retrieval
char buffer[256];
DWORD size = sizeof(buffer);
pTexture->GetPrivateData(GUID_TextureName, buffer, &size);
```

**Limitations**:
- Only works for textures YOU create
- GTA's textures won't have this data
- GUID must be unique and consistent

---

## File Reference Summary

### Key Implementation Files

1. **Lua Bindings**:
   - `Client/mods/deathmatch/logic/luadefs/CLuaEngineDefs.cpp`
   - `Client/mods/deathmatch/logic/luadefs/CLuaEngineDefs.h`

2. **Texture Tracking**:
   - `Client/core/Graphics/CRenderItemManager.h`
   - `Client/core/Graphics/CRenderItemManager.TextureReplace.cpp`

3. **RenderWare Integration**:
   - `Client/sdk/game/CRenderWare.h` (interface)
   - `Client/game_sa/CRenderWareSA.h` (implementation)
   - `Client/game_sa/CRenderWareSA.cpp`
   - `Client/game_sa/CRenderWareSA.TextureReplacing.cpp`
   - `Client/game_sa/CRenderWareSA.ShaderSupport.h`

4. **Interfaces**:
   - `Client/sdk/core/CRenderItemManagerInterface.h`

---

## Code Snippets

### GetTextureName Implementation

```cpp
// From CRenderWareSA (inferred from usage)
const char* CRenderWareSA::GetTextureName(CD3DDUMMY* pD3DData)
{
    // Lookup in tracking map
    auto it = m_D3DDataTexInfoMap.find(pD3DData);
    if (it != m_D3DDataTexInfoMap.end())
    {
        STexInfo* pTexInfo = it->second;
        return pTexInfo->strTextureName.c_str();
    }
    return "";  // Empty string if not found
}
```

### Texture Usage Tracking (Rendering Hook)

```cpp
// CRenderItemManager::GetAppliedShaderForD3DData
SShaderItemLayers* CRenderItemManager::GetAppliedShaderForD3DData(CD3DDUMMY* pD3DData)
{
    // Track texture usage for this frame
    MapInsert(m_FrameTextureUsage, pD3DData);

    // Get shader layers from RenderWare system
    return m_pRenderWare->GetAppliedShaderForD3DData(pD3DData);
}
```

### Model Texture Enumeration

```cpp
// From CRenderWareSA.TextureReplacing.cpp
void GetTxdTextures(std::vector<RwTexture*>& outTextureList, RwTexDictionary* pTXD)
{
    if (!pTXD) return;

    // Iterate linked list in TXD
    RwListEntry* node = pTXD->textures.root.next;
    while (node != &pTXD->textures.root)
    {
        // Container_of pattern to get RwTexture from list node
        RwTexture* pTexture = CONTAINING_RECORD(node, RwTexture, TXDList);
        outTextureList.push_back(pTexture);
        node = node->next;
    }
}
```

---

## Conclusion

MTA-Blue's texture API works by:

1. **Intercepting** GTA's RenderWare texture streaming
2. **Extracting** texture names from `RwTexture::name` (32-byte char array)
3. **Storing** names in separate `STexInfo` structures
4. **Mapping** DirectX texture pointers to these structures via hash maps
5. **Tracking** per-frame texture usage for visibility queries

**The texture name is NEVER stored in the DirectX texture itself** - it exists only in MTA's parallel tracking system. This is the correct approach because D3D9 textures have no native name storage.

For your screenshot module, if you need texture names, you must either:
- Hook into MTA's existing tracking (if building an MTA module)
- Build similar tracking by hooking texture creation/loading
- Use `SetPrivateData` for your own textures only

DirectX alone cannot provide this information.
