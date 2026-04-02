# Plan implementacji rozszerzenia Godot (GDExtension, C/C++)

## 1. Cel i zakres

Celem jest przygotowanie rozszerzenia typu **GDExtension** dla Godot 4.x, napisanego w C/C++, które:
- dostarcza logikę wysokowydajną (native),
- jest wygodne dla twórców gier (czytelne API po stronie Godot),
- jest łatwe do budowania i dystrybucji na wiele platform.

Zakres dokumentu obejmuje:
1. architekturę implementacji,
2. workflow techniczny (build, testy, wersjonowanie),
3. wzorzec projektowania API dla użytkownika końcowego (twórcy w Godot),
4. plan wdrożenia krok po kroku.

---

## 2. Podstawy: jak działają rozszerzenia w Godot 4

W Godot 4 oficjalnym podejściem do natywnych rozszerzeń jest **GDExtension**:
- kod C/C++ kompilowany jest do biblioteki współdzielonej (`.dll`, `.so`, `.dylib`),
- silnik ładuje ją przez plik konfiguracyjny `.gdextension`,
- klasy C++ są rejestrowane do ClassDB i stają się dostępne w GDScript/C# oraz edytorze.

Typowe elementy:
- `godot-cpp` (bindingi C++ do API Godot),
- plik wejściowy z funkcją inicjalizacji/terminacji rozszerzenia,
- klasy dziedziczące po `godot::Object`, `godot::Node`, `godot::Resource` itd.,
- rejestracja metod, właściwości, sygnałów oraz stałych.

---

## 3. Architektura techniczna (proponowana)

## 3.1 Warstwy

1. **Warstwa native core (C/C++)**
   - algorytmy, obliczenia, integracje z bibliotekami C/C++,
   - brak zależności od API Godot tam, gdzie to możliwe.

2. **Warstwa adaptera Godot (GDExtension glue)**
   - klasy eksponowane do Godot,
   - mapowanie typów (`String`, `Array`, `Dictionary`, `Packed*Array`, `Variant`) na typy domenowe.

3. **Warstwa API dla użytkownika Godot**
   - klasy i metody, które widzi twórca gry,
   - sygnały, properties, enumy,
   - opcjonalnie cienka warstwa GDScript (helpery, ergonomia).

## 3.2 Struktura katalogów (propozycja)

```text
extension/
  include/
  src/
    core/
    godot/
      register_types.cpp
      extension_entry.cpp
  tests/
project/
  addons/<nazwa_addonu>/
    <nazwa>.gdextension
    icons/
    plugin.cfg (jeśli EditorPlugin)
```

---

## 4. Implementacja w C/C++: standard pracy

## 4.1 Narzędzia

- C++17 lub C++20 (spójnie w projekcie),
- SCons lub CMake (najczęściej z gotowymi skryptami `godot-cpp`),
- `godot-cpp` zgodne z docelową wersją Godot (np. 4.2/4.3/4.4),
- CI: budowanie bibliotek dla targetów (Windows/Linux/macOS).

## 4.2 Rejestracja klas

W `register_types.cpp`:
- `GDREGISTER_CLASS(MyNode)` dla klas instancjonowalnych,
- `GDREGISTER_ABSTRACT_CLASS(...)` gdy klasa bazowa,
- metody przez `ClassDB::bind_method`,
- właściwości przez `ADD_PROPERTY`.

W klasie:
- `_bind_methods()` jako centralne miejsce kontraktu API,
- jawne definicje argumentów i wartości domyślnych,
- możliwie stabilne sygnatury metod (ważne dla kompatybilności).

## 4.3 Żywotność i bezpieczeństwo

- unikać manualnego `new/delete` jeśli można użyć RAII,
- w interfejsie Godot unikać surowych wskaźników na obiekty o niejasnej własności,
- walidować wejście z GDScript (typ, zakres, null),
- obsługiwać błędy przez:
  - bezpieczne wartości zwrotne,
  - `ERR_FAIL_*` / `UtilityFunctions::push_error` tam, gdzie uzasadnione.

## 4.4 Wydajność

- ograniczać koszt konwersji `Variant` <-> typy natywne,
- dla dużych danych preferować `Packed*Array` i przetwarzanie wsadowe,
- unikać alokacji w gorących pętlach,
- dokumentować złożoność metod „ciężkich”.

---

## 5. API dla twórców gier w Godot: zasady projektowe

## 5.1 Kontrakt API (co widzi użytkownik)

API powinno być:
- **idiomatyczne dla Godot** (nazwy, typy, sygnały),
- **czytelne w Inspectorze** (właściwości z hintami),
- **przewidywalne** (spójne nazewnictwo i side-effecty).

W praktyce:
- metody `snake_case` zgodnie z konwencją Godot,
- krótkie, semantyczne nazwy (`set_config`, `run_step`, `reset_state`),
- sygnały dla zdarzeń asynchronicznych (`completed`, `failed`, `progress_changed`),
- enumy zamiast „magicznych intów”.

## 5.2 Typy klas i ich przeznaczenie

- `Node` / `Node3D`: gdy obiekt ma żyć w drzewie sceny,
- `Resource`: gdy konfiguracja/dane mają być serializowalne i współdzielone,
- `RefCounted`: gdy to narzędzie/usługa bez obecności w scenie.

## 5.3 Przykładowy styl API

Zamiast pojedynczej metody „kombajn”:
- lepiej:
  - `configure(resource)`
  - `start()`
  - `cancel()`
  - `get_status()`

To ułatwia użycie w GDScript i integrację z narzędziami edytora.

## 5.4 Dokumentacja dla użytkownika

Minimalny pakiet dokumentacyjny:
1. „Quick start” (3–5 minut),
2. referencja klas i metod,
3. ograniczenia/platform support,
4. changelog kompatybilności.

---

## 6. Plan implementacji (iteracyjny)

## Etap 0 — przygotowanie

- [ ] wybrać docelową wersję Godot (np. 4.3.x),
- [ ] przypiąć wersję `godot-cpp` kompatybilną z tą wersją,
- [ ] ustalić system builda i baseline CI.

## Etap 1 — szkielet rozszerzenia

- [ ] dodać plik `.gdextension`,
- [ ] przygotować `extension_entry.cpp` i `register_types.cpp`,
- [ ] zarejestrować 1 klasę testową (np. `ExampleService`),
- [ ] zweryfikować ładowanie w pustym projekcie Godot.

**Kryterium ukończenia:** klasa widoczna i tworzy się z poziomu edytora/skryptu.

## Etap 2 — API v0

- [ ] zaimplementować pierwszy minimalny use-case biznesowy,
- [ ] dodać sygnały + properties + walidację błędów,
- [ ] napisać scenę demonstracyjną i przykładowy skrypt.

**Kryterium ukończenia:** twórca gry potrafi użyć rozszerzenia bez czytania kodu C++.

## Etap 3 — jakość i testy

- [ ] testy jednostkowe warstwy native core,
- [ ] smoke test uruchomienia w Godot (headless),
- [ ] test zgodności API (brak niezamierzonych zmian sygnatur).

**Kryterium ukończenia:** green CI na wspieranych platformach.

## Etap 4 — wydajność i stabilność

- [ ] profilowanie ścieżek krytycznych,
- [ ] eliminacja zbędnych alokacji i konwersji Variant,
- [ ] testy regresji pamięci i długich sesji.

**Kryterium ukończenia:** stabilne działanie pod obciążeniem referencyjnym.

## Etap 5 — publikacja i utrzymanie

- [ ] paczka binarna per platforma + instrukcja instalacji,
- [ ] semver (`MAJOR.MINOR.PATCH`) dla API,
- [ ] polityka deprecacji (min. 1 wersja przejściowa).

**Kryterium ukończenia:** powtarzalny release i przewidywalna kompatybilność.

---

## 7. Jak twórcy Godot będą korzystać z API (przepływ)

1. Instalują addon (kopiują katalog `addons/...` do projektu).
2. Godot ładuje bibliotekę przez `.gdextension`.
3. Twórca dodaje node/zasób z Twojej klasy w edytorze lub tworzy go skryptem.
4. Ustawia właściwości w Inspectorze i podpina sygnały.
5. Wywołuje metody z GDScript/C#.

Przykładowy przepływ GDScript:
- utwórz instancję klasy,
- skonfiguruj parametry,
- podłącz sygnał `completed`,
- wywołaj `start()`.

---

## 8. Decyzje projektowe do podjęcia teraz

1. **Typ głównej klasy API**: `Node` czy `Resource`?
2. **Poziom stabilności API**: eksperymentalne czy od razu semver-stable?
3. **Zakres platform**: desktop-only vs desktop+mobile.
4. **Narzędzie builda**: SCons vs CMake (i konsekwencja w CI).
5. **Granica odpowiedzialności**: co zostaje w C++, a co celowo w GDScript.

---

## 9. Rekomendacja startowa (praktyczna)

Najbezpieczniejszy start:
- zacząć od małego API (`1 klasa`, `3–5 metod`, `1–2 sygnały`),
- zbudować przykładową scenę pokazującą realny workflow,
- dopiero potem rozszerzać funkcje i optymalizować.

To minimalizuje ryzyko „dużego” API, które trudno utrzymać.

---

## 10. Doprecyzowanie dla tego pluginu (Semi-Fixed Tick)

W tym projekcie plugin ma pełnić rolę **utility layer**, a nie runtime orchestratora symulacji:
- plugin wylicza semi-fixed kroki i `alpha`,
- plugin udostępnia interpolację oznaczonych pól,
- logika symulacji i kolejność jej wykonywania pozostają po stronie gry.

To podejście ogranicza coupling i lepiej skaluje się w projektach z wieloma niezależnymi subsystemami symulacji.
