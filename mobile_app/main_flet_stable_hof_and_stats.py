print("ROOT: Script loaded")
import sys
import os
import flet as ft
from datetime import datetime, timezone

# Añadir path para encontrar imports
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)
sys.path.append(os.path.join(current_dir, 'src'))

# Imports locales (si fallan, se usarán mocks)
try:
    from shared.models import Consistency, KKEvent
    from kkcos.api import APIClient
except ImportError as e:
    print(f"Warning: Local imports failed. Using mocks. Error: {e}")
    Consistency = None
    KKEvent = None
    APIClient = None

# --- Constants ---
BG_COLOR = "#000000"
CARD_COLOR = "#1C1C1E"
ACCENT_COLOR = "#C67C4E" # Modern Brown
TEXT_COLOR = "#FFFFFF"


# --- Storage Helpers ---
import logging
import json

async def save_session(page, user_data):
    try:
        logging.info(f"Saving session for {user_data}")
        # Try client_storage
        if hasattr(page, "client_storage") and page.client_storage:
             page.client_storage.set("kkcos_auth", user_data)
             return True
        # Try shared_preferences (deprecated but available)
        elif hasattr(page, "shared_preferences") and page.shared_preferences:
             # Use .set() - ensure string for compatibility if it doesn't handle objects
             # Await the coroutine
             await page.shared_preferences.set("kkcos_auth", json.dumps(user_data))
             return True
        else:
             logging.error("No storage mechanism found.")
             return False
    except Exception as e:
        logging.error(f"Error saving session: {e}")
        return False

async def get_session(page):
    try:
        data = None
        # Try client_storage
        if hasattr(page, "client_storage") and page.client_storage:
             if page.client_storage.contains_key("kkcos_auth"):
                 data = page.client_storage.get("kkcos_auth")
        
        # Try shared_preferences
        if not data and hasattr(page, "shared_preferences") and page.shared_preferences:
             val = await page.shared_preferences.get("kkcos_auth") # Await here
             logging.warning(f"DEBUG: shared_preferences raw get: {val}, type: {type(val)}")
             if val:
                 if isinstance(val, str):
                     try:
                        data = json.loads(val)
                     except Exception as e:
                        logging.warning(f"JSON decode failed for {val}: {e}")
                        data = val # Fallback? likely invalid if expecting dict
                 else:
                     data = val
        return data
    except Exception as e:
        logging.error(f"Error getting session: {e}")
        return None

async def clear_session_storage(page):
    try:
         if hasattr(page, "client_storage") and page.client_storage:
             page.client_storage.remove("kkcos_auth")
         if hasattr(page, "shared_preferences") and page.shared_preferences:
             await page.shared_preferences.remove("kkcos_auth") # Await here
    except Exception as e:
        logging.error(f"Error clearing session: {e}")

async def main(page: ft.Page):
    print("DEBUG: Entering main")
    page.title = "KKCoS"
    page.theme_mode = "dark"
    page.bgcolor = BG_COLOR
    page.padding = 10
    
    print("DEBUG: Page configuration set")

    # State for current user
    current_user = {"id": None, "username": None}

    # Intentar inicializar API
    api = None
    if APIClient:
        try:
            print("DEBUG: Initializing APIClient...")
            api = APIClient()
            print("DEBUG: APIClient initialized")
        except Exception as e:
            print(f"DEBUG: APIClient init failed: {e}")
            pass
            
    # --- Views ---
    
    def view_login():
        print("DEBUG: Entering view_login")
        # Login Mode vs Register Mode vs Recovery Mode
        mode = ["login"] # login, register, recovery

        username_field = ft.TextField(label="Usuario", bgcolor=CARD_COLOR, color=TEXT_COLOR, border_radius=10, width=280)
        password_field = ft.TextField(label="Contraseña", password=True, can_reveal_password=True, bgcolor=CARD_COLOR, color=TEXT_COLOR, border_radius=10, width=280)
        email_field = ft.TextField(label="Email", bgcolor=CARD_COLOR, color=TEXT_COLOR, border_radius=10, width=280, visible=False) # Initially hidden
        
        # Separate buttons for clarity and reliable event handling
        btn_login = ft.FilledButton("Entrar", bgcolor=ACCENT_COLOR, color="black", width=280, height=50)
        btn_register = ft.FilledButton("Registrarse", bgcolor=ACCENT_COLOR, color="black", width=280, height=50, visible=False)
        btn_recover = ft.FilledButton("Recuperar Contraseña", bgcolor=ACCENT_COLOR, color="black", width=280, height=50, visible=False)
        
        btn_toggle = ft.TextButton("¿Nuevo? Regístrate aquí")
        btn_forgot = ft.TextButton("¿Olvidaste tu contraseña?", visible=True)

        def update_ui():
            if mode[0] == "login":
                username_field.visible = True
                password_field.visible = True
                email_field.visible = False
                
                btn_login.visible = True
                btn_register.visible = False
                btn_recover.visible = False
                
                btn_toggle.text = "¿Nuevo? Regístrate aquí"
                btn_toggle.on_click = toggle_mode
                btn_forgot.visible = True
                
            elif mode[0] == "register":
                username_field.visible = True
                password_field.visible = True
                email_field.visible = True
                
                btn_login.visible = False
                btn_register.visible = True
                btn_recover.visible = False
                
                btn_toggle.text = "¿Ya tienes cuenta? Entra"
                btn_toggle.on_click = toggle_mode
                btn_forgot.visible = False

            elif mode[0] == "recovery":
                username_field.visible = False
                password_field.visible = False
                email_field.visible = True
                email_field.label = "Introduce tu Email"
                
                btn_login.visible = False
                btn_register.visible = False
                btn_recover.visible = True
                
                btn_toggle.text = "Volver al Login"
                btn_toggle.on_click = toggle_mode_login
                btn_forgot.visible = False
            
            page.update()

        def toggle_mode(e):
            mode[0] = "register" if mode[0] == "login" else "login"
            update_ui()
        
        def toggle_mode_login(e):
             mode[0] = "login"
             email_field.label = "Email"
             update_ui()

        def go_to_recovery(e):
            mode[0] = "recovery"
            update_ui()

        btn_forgot.on_click = go_to_recovery
        
        async def handle_login(e):
            if not api: return
            res = api.login(username_field.value, password_field.value)
            if res:
                current_user["id"] = res["user_id"]
                current_user["username"] = res["username"]
                
                # Save session safely
                await save_session(e.page, {"id": res["user_id"], "username": res["username"]})

                e.page.snack_bar = ft.SnackBar(ft.Text(f"Bienvenido, {res['username']}!"))
                e.page.snack_bar.open = True
                show_main_app()

            else:
                page.snack_bar = ft.SnackBar(ft.Text("Usuario o contraseña incorrectos"))
                page.snack_bar.open = True
                page.update()

        def handle_register(e):
            if not api: return
            
            # Email Validation
            import re
            email_regex = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
            
            if not email_field.value:
                page.snack_bar = ft.SnackBar(ft.Text("El email es obligatorio"))
                page.snack_bar.open = True
                page.update()
                return

            if not re.match(email_regex, email_field.value):
                page.snack_bar = ft.SnackBar(ft.Text("Formato de email incorrecto"))
                page.snack_bar.open = True
                page.update()
                return

            res = api.register(username_field.value, password_field.value, email_field.value)
            if res:
                page.snack_bar = ft.SnackBar(ft.Text("Acabas de ser registrado en KKpenco"))
                page.snack_bar.open = True
                
                # Auto-login after registration or just switch to login?
                # User asked: "Después debe permitir entrar con ese perfil"
                # This implies explicit login action or auto-login.
                # I'll switch to login view for now as requested by flow "Después debe permitir entrar..." 
                # usually implies "now go login".
                toggle_mode_login(None) 
            else:
                page.snack_bar = ft.SnackBar(ft.Text("Error: Usuario o Email ya existen."))
                page.snack_bar.open = True
                page.update()

        def handle_recovery(e):
             if not api: return
             if not email_field.value:
                 page.snack_bar = ft.SnackBar(ft.Text("Introduce tu email"))
                 page.snack_bar.open = True
                 page.update()
                 return
             
             success = api.recover_password(email_field.value)
             if success:
                 page.snack_bar = ft.SnackBar(ft.Text("Correo de recuperación enviado (simulado)."))
             else:
                 page.snack_bar = ft.SnackBar(ft.Text("Error al solicitar recuperación."))
             page.snack_bar.open = True
             toggle_mode_login(None)

        # Connect handlers
        btn_login.on_click = handle_login
        btn_register.on_click = handle_register
        btn_recover.on_click = handle_recovery

        # Initialize UI
        update_ui()

        return ft.Column(
            alignment=ft.MainAxisAlignment.CENTER,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            expand=True,
            controls=[
                 ft.Text("KKCoS", size=40, weight="bold", color=ACCENT_COLOR),
                 ft.Text("Comunidad de Excreción", size=16, color="grey"),
                 ft.Container(height=40),
                 
                 # Input Stack
                 username_field,
                 ft.Container(height=10),
                 password_field,
                 ft.Container(height=10),
                 email_field,
                 
                 ft.Container(height=30),
                 # Buttons stack
                 btn_login,
                 btn_register,
                 btn_recover,
                 
                 ft.Container(height=10),
                 btn_toggle,
                 btn_forgot
            ]
        )
    
    def view_tracker():
        # State for consistency (default Normal)
        selected_cons = ["Normal"] 

        # Helper to update button styles
        def update_buttons():
            val = selected_cons[0]
            btn_normal.bgcolor = ACCENT_COLOR if val == "Normal" else "#424242"
            btn_normal.color = "black" if val == "Normal" else TEXT_COLOR
            
            btn_jurasica.bgcolor = ACCENT_COLOR if val == "Jurásica" else "#424242"
            btn_jurasica.color = "black" if val == "Jurásica" else TEXT_COLOR

            btn_espurruteo.bgcolor = ACCENT_COLOR if val == "Espurruteo" else "#424242"
            btn_espurruteo.color = "black" if val == "Espurruteo" else TEXT_COLOR
            page.update()

        def set_cons(e):
            selected_cons[0] = e.control.data
            update_buttons()

        # Buttons definition
        button_style = ft.ButtonStyle(text_style=ft.TextStyle(size=16, weight="bold"))
        btn_normal = ft.FilledButton("Normal", data="Normal", on_click=set_cons, bgcolor=ACCENT_COLOR, color="black", width=135, height=60, style=button_style)
        btn_jurasica = ft.FilledButton("Jurásica", data="Jurásica", on_click=set_cons, bgcolor="#424242", color=TEXT_COLOR, width=135, height=60, style=button_style)
        btn_espurruteo = ft.FilledButton("Espurruteo", data="Espurruteo", on_click=set_cons, bgcolor="#424242", color=TEXT_COLOR, width=135, height=60, style=button_style)

        notes_txt = ft.TextField(label="Notas", bgcolor=CARD_COLOR, color=TEXT_COLOR, border_radius=10)

        def on_log(e):
            if not api:
                page.snack_bar = ft.SnackBar(ft.Text("Modo Offline: KK guardada localmente (simulación)."))
                page.snack_bar.open = True
                page.update()
                return

            try:
                # Create Event Object
                # Map string to Enum if possible, or pass string direct since it is str, Enum
                # Ensure we use the shared model if available
                
                new_event = KKEvent(
                    user_id=current_user["id"] or 1, # Use logged user or fallback
                    consistency=Consistency(selected_cons[0]), # Explicit Enum cast
                    notes=notes_txt.value or "",
                    timestamp=datetime.now(timezone.utc)
                )
                
                success = api.create_event(new_event)
                
                if success:
                    page.snack_bar = ft.SnackBar(ft.Text(f"¡Éxito! KK {selected_cons[0]} registrada en la nube."))
                    notes_txt.value = "" # Clear notes
                else:
                    page.snack_bar = ft.SnackBar(ft.Text("Error: No se pudo conectar con el servidor."))
            
            except Exception as ex:
                import traceback
                traceback.print_exc()
                page.snack_bar = ft.SnackBar(ft.Text(f"Error: {str(ex)}"))
            
            page.snack_bar.open = True
            page.update()
        
        return ft.Column(
            scroll="auto",
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Container(height=10), # Small spacer from top
                
                # Main Button "KKApenco"
                ft.Container(
                    alignment=ft.Alignment(0, 0),
                    content=ft.Column(
                        horizontal_alignment="center",
                        controls=[
                            ft.FilledButton(
                                "KKApenco",
                                icon="add",
                                bgcolor=ACCENT_COLOR,
                                color="black",
                                style=ft.ButtonStyle(
                                    shape=ft.RoundedRectangleBorder(radius=20),
                                    padding=20,
                                    text_style=ft.TextStyle(size=20, weight="bold")
                                ),
                                width=220,
                                height=70,
                                on_click=on_log
                            )
                        ]
                    )
                ),
                ft.Container(height=30),
                
                # Details Form
                ft.Container(
                    bgcolor=CARD_COLOR,
                    padding=30, # More padding
                    border_radius=25,
                    margin=ft.Margin.symmetric(horizontal=15), # Responsive margin
                    alignment=ft.Alignment(0, 0),
                    content=ft.Column([
                        ft.Text("Registra tu caca", size=28, weight="bold", text_align="center"),
                        
                        # Image Placeholder
                        ft.Container(
                            height=180, # Bigger image area
                            bgcolor="#8A000000", # Black54 substitute
                            border_radius=15,
                            alignment=ft.Alignment(0, 0),
                            content=ft.Icon("image", size=60, color="grey"), # Bigger icon
                            margin=ft.Margin.only(bottom=20)
                        ),

                        # Consistency Buttons Row
                        ft.Text("Consistencia", size=18, color=TEXT_COLOR), # Bigger label
                        ft.Row(
                            alignment=ft.MainAxisAlignment.SPACE_EVENLY,
                            controls=[
                                btn_normal,
                                btn_jurasica,
                                btn_espurruteo
                            ],
                            wrap=True,
                            spacing=10
                        ),
                        
                        ft.Container(height=15),
                        ft.TextField(label="Notas", bgcolor=CARD_COLOR, color=TEXT_COLOR, border_radius=15, text_size=16, content_padding=20),
                        ft.Container(height=15),
                        
                        ft.FilledButton(
                            on_click=on_log, 
                            bgcolor=ACCENT_COLOR, 
                            color="black", 
                            width=None, # Auto width to fill container?
                            expand=True, # Needs to be in a row/col with expansion logic usually, but in Column it fills width if cross_alignment is stretch.
                            # But here cross_alignment is center. 
                            # Let's set a very large width so it gets clamped by container padding.
                            style=ft.ButtonStyle(
                                shape=ft.RoundedRectangleBorder(radius=15),
                                padding=15,
                            ),
                            height=60,
                            content=ft.Text("Guardar KK", size=20, weight="bold")
                        ),
                        ft.Container(height=15),
                        ft.FilledButton(
                            on_click=lambda _: on_nav_tap(4), # Go to History
                            bgcolor="#333333", 
                            color="white", 
                            style=ft.ButtonStyle(
                                shape=ft.RoundedRectangleBorder(radius=15),
                                padding=15,
                            ),
                            height=50,
                            content=ft.Text("Revisa tu mierda", size=18, weight="bold")
                        )
                    ], horizontal_alignment=ft.CrossAxisAlignment.STRETCH) # Stretch content to fill container
                )
            ]
        )

    def view_ranking():
        
        # Ranking Table
        ranking_table = ft.DataTable(
            width=350,
            bgcolor="#2C2C2E",
            border=ft.border.all(1, "#444444"),
            border_radius=10,
            vertical_lines=ft.border.BorderSide(1, "#444444"),
            horizontal_lines=ft.border.BorderSide(1, "#444444"),
            columns=[
                ft.DataColumn(ft.Text("Puesto", weight="bold", color=TEXT_COLOR), numeric=True),
                ft.DataColumn(ft.Text("Usuario", weight="bold", color=TEXT_COLOR)),
                ft.DataColumn(ft.Text("Cacas", weight="bold", color=ACCENT_COLOR), numeric=True),
            ],
            rows=[]
        )
        
        ranking_container = ft.Column(
             scroll="auto",
             horizontal_alignment=ft.CrossAxisAlignment.CENTER,
             controls=[
                ft.Text("Ranking", size=30, weight="bold", color=TEXT_COLOR, text_align="center"),
                ft.Container(height=20),
                ranking_table
             ]
        )

        def load_ranking():
            if not api:
                ranking_table.rows.append(
                    ft.DataRow(cells=[ft.DataCell(ft.Text("Offline")) for _ in range(3)])
                )
                return

            ranking_data = api.get_ranking()
            ranking_table.rows.clear()
            
            if not ranking_data:
                ranking_table.rows.append(
                    ft.DataRow(cells=[
                        ft.DataCell(ft.Text("-")),
                        ft.DataCell(ft.Text("Sin datos")),
                        ft.DataCell(ft.Text("0"))
                    ])
                )
            else:
                for idx, entry in enumerate(ranking_data):
                    rank = idx + 1
                    username = entry.get("username", "Desconocido")
                    count = entry.get("count", 0)
                    
                    # Medal visualization
                    medal = ""
                    if rank == 1: medal = "🥇 "
                    elif rank == 2: medal = "🥈 "
                    elif rank == 3: medal = "🥉 "
                    
                    user_display = f"{medal}{username}"

                    ranking_table.rows.append(
                        ft.DataRow(
                            cells=[
                                ft.DataCell(ft.Text(str(rank), color=TEXT_COLOR)),
                                ft.DataCell(ft.Text(user_display, color=TEXT_COLOR)),
                                ft.DataCell(ft.Text(str(count), weight="bold", color=ACCENT_COLOR)),
                            ]
                        )
                    )
            # if ranking_container.page:
            #    ranking_container.update()
            
        def load_stats():
            if not api:
                return

            stats = api.get_statistics()
            if not stats:
                return

            # Hall of Fame
            hof_data = stats.get("hall_of_fame", {})
            hof_controls = []
            
            categories = [
                {"key": "monstruoso", "title": "Cagador Monstruoso", "icon": "local_fire_department", "gradient_colors": ["#FF416C", "#FF4B2B"]},
                {"key": "escopetas", "title": "El Escopetas", "icon": "scatter_plot", "gradient_colors": ["#F2994A", "#F2C94C"]}, # Orange/Yellow for explosive
                {"key": "timido", "title": "El Tímido", "icon": "visibility_off", "gradient_colors": ["#2193b0", "#6dd5ed"]}
            ]

            print(f"DEBUG: Processing Hall of Fame data: {hof_data}")

            for cat in categories:
                data = hof_data.get(cat["key"]) or {} # Default to empty dict if None
                
                # Default values
                username = data.get("username") or "Vacante"
                count = data.get("count", 0)
                
                # Display text logic
                count_text = f"{count}" if data.get("username") else "-"
                
                hof_controls.append(
                    ft.Container(
                        gradient=ft.LinearGradient(
                            begin=ft.Alignment(-1.0, -1.0),
                            end=ft.Alignment(1.0, 1.0),
                            colors=cat["gradient_colors"]
                        ),
                        padding=10,
                        border_radius=15,
                        width=110, # Maximize width for 350px container (110*3 + 20 spacing = 350)
                        height=150, # Taller
                        shadow=ft.BoxShadow(
                            spread_radius=1,
                            blur_radius=5,
                            color="#4C000000",
                            offset=ft.Offset(0, 3),
                        ),
                        content=ft.Column([
                            # 1. Category Top
                            ft.Text(cat["title"], size=11, weight="bold", color="white", text_align="center", no_wrap=False, max_lines=2, height=35),
                            
                            # 2. BIG NUMBER Middle
                            ft.Text(f"{count}", size=40, weight="bold", color="white", text_align="center"),
                            
                            # 3. Username Bottom
                            ft.Text(str(username), size=13, color="white", weight="bold", text_align="center", max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                            
                        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=0, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
                    )
                )

            # Update container to be a Row again
            hof_list.controls = hof_controls
            hof_section.visible = True
            
            # Averages
            avg_data = stats.get("averages", [])
            averages_table.rows.clear()
            
            # Sort by average desc
            avg_data.sort(key=lambda x: x["average"], reverse=True)
            
            for entry in avg_data:
                averages_table.rows.append(
                    ft.DataRow(cells=[
                         ft.DataCell(ft.Text(entry["username"], color=TEXT_COLOR)),
                         ft.DataCell(ft.Text(f"{entry['average']:.2f}", weight="bold", color=ACCENT_COLOR)),
                    ])
                )
            
            if avg_data:
                averages_section.visible = True
                
            # if ranking_container.page:
            #    ranking_container.update()

        # Init sections
        hof_list = ft.Row(spacing=10, alignment=ft.MainAxisAlignment.CENTER)
        hof_section = ft.Column([
            ft.Container(height=20),
            ft.Text("🏆 Hall of Fame", size=24, weight="bold", color=TEXT_COLOR),
            ft.Container(height=10),
            ft.Container(
                content=hof_list,
                width=350, # Match table width
                bgcolor="transparent", 
            )
        ], visible=False, horizontal_alignment=ft.CrossAxisAlignment.CENTER)
        
        averages_table = ft.DataTable(
            width=350,
            bgcolor="#2C2C2E",
            border=ft.border.all(1, "#444444"),
            border_radius=10,
            columns=[
                ft.DataColumn(ft.Text("Usuario", weight="bold", color=TEXT_COLOR)),
                ft.DataColumn(ft.Text("Media Diaria", weight="bold", color=TEXT_COLOR), numeric=True),
            ],
            rows=[]
        )
        
        averages_section = ft.Column([
            ft.Container(height=20),
            ft.Text("📊 Media Diaria", size=24, weight="bold", color=TEXT_COLOR),
            averages_table
        ], visible=False, horizontal_alignment=ft.CrossAxisAlignment.CENTER)

        # Add new sections to container
        ranking_container.controls.extend([hof_section, averages_section])

        # Load data immediately
        load_ranking()
        load_stats()
        
        return ranking_container

    def view_history():
        header = ft.Text("Tu Mierda", size=28, weight="bold", color=TEXT_COLOR, text_align="center")
        
        # Container for the list
        list_container = ft.ListView(expand=True, spacing=10, padding=20)

        # Helper to delete item
        def delete_item(e):
             event_id = e.control.data
             if api and api.delete_event(event_id):
                 page.snack_bar = ft.SnackBar(ft.Text("KK eliminada correctamente."))
                 page.snack_bar.open = True
                 # Refresh list logic: simplest way is to re-render the view
                 # Ideally we should manipulate the list control, but reloading view is easier for now
                 on_nav_tap(4) 
             else:
                 page.snack_bar = ft.SnackBar(ft.Text("Error al eliminar KK."))
                 page.snack_bar.open = True
                 page.update()
        
        if not api:
            list_container.controls.append(ft.Text("Modo Offline (Sin conexión)", color="red", text_align="center"))
        else:
            try:
                data = api.get_events()
                if not data:
                    list_container.controls.append(
                        ft.Container(
                            padding=40,
                            content=ft.Text("Aún no hay registros.\n¡Estrena el trono!", text_align="center", color="grey")
                        )
                    )
                else:
                    # Show newest first
                    for item in reversed(data):
                        timestamp = item.get("timestamp", "")
                        display_time = timestamp.replace("T", " ")[:16]
                        consistency = item.get("consistency", "N/A")
                        notes = item.get("notes") or "Sin notas"
                        event_id = item.get("id")
                        
                        card = ft.Container(
                            bgcolor=CARD_COLOR,
                            padding=15,
                            border_radius=15,
                            content=ft.Column([
                                ft.Row([
                                    # Delete Button
                                    ft.IconButton(
                                        icon=ft.icons.Icons.CLOSE, 
                                        icon_color="red",
                                        data=event_id, 
                                        on_click=delete_item,
                                        tooltip="Eliminar registro"
                                    ),
                                    # Info
                                    ft.Column([
                                        ft.Text(consistency, weight="bold", size=18, color=ACCENT_COLOR),
                                        ft.Text(display_time, size=12, color="grey")
                                    ], expand=True), # Expand text column so button stays left
                                ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER),
                                
                                ft.Container(height=5),
                                ft.Text(notes, size=15, color=TEXT_COLOR, italic=True if notes == "Sin notas" else False)
                            ])
                        )
                        list_container.controls.append(card)
                        
            except Exception as e:
                list_container.controls.append(ft.Text(f"Error al cargar datos: {str(e)}", color="red"))

        return ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Container(height=10),
                header,
                ft.Container(expand=True, content=list_container), # Use expand to fill remaining space
                ft.Container(height=20, content=ft.ElevatedButton("Volver", on_click=lambda _: on_nav_tap(0), bgcolor="#333", color="white"))
            ]
        )

    def view_cos():
         
         # Members List
         members_list = ft.Column(scroll="auto", spacing=10)
         
         def load_members():
             if api:
                 users = api.get_users()
                 members_list.controls.clear()
                 if not users:
                     members_list.controls.append(ft.Text("No hay miembros visibles.", color="grey"))
                 else:
                     for u in users:
                         is_me = (u["id"] == current_user["id"])
                         members_list.controls.append(
                             ft.Container(
                                 bgcolor=CARD_COLOR,
                                 padding=15,
                                 border_radius=10,
                                 content=ft.Row([
                                     ft.Icon("person", color=ACCENT_COLOR if is_me else "grey"),
                                     ft.Text(u["username"] + (" (Tú)" if is_me else ""), size=16, weight="bold" if is_me else "normal")
                                 ])
                             )
                         )
                 page.update()

         load_members()

         return ft.Column(
            scroll="auto",
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Text("Comunidad (COS)", size=30, weight="bold", color=TEXT_COLOR, text_align="center"),
                ft.Container(height=20),
                ft.Text(f"Bienvenido, {current_user['username']}", color=ACCENT_COLOR),
                ft.Container(height=20),
                ft.Text("Miembros", size=20, weight="bold", color=TEXT_COLOR),
                ft.Container(height=10),
                members_list
            ]
        )

    def view_profile():
        
        async def handle_logout(e):
            await clear_session_storage(page)
            current_user["id"] = None
            current_user["username"] = None
            
            # Reset UI to Login
            page.clean()
            page.add(view_login())
            page.update()

        return ft.Column(
            scroll="auto",
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Text("Perfil", size=30, weight="bold", color=TEXT_COLOR, text_align="center"),
                ft.Container(height=20),
                ft.Container(
                    bgcolor=CARD_COLOR,
                    padding=20,
                    border_radius=15,
                    width=300,
                    content=ft.Column([
                        ft.Text("Usuario", color="grey", size=14),
                        ft.Text(current_user["username"] or "Invitado", size=20, weight="bold", color=TEXT_COLOR),
                        ft.Container(height=20),
                        ft.FilledButton("Cerrar Sesión", on_click=handle_logout, bgcolor="#444", color="white", width=260)
                    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)
                )
            ]
        )

    # --- Custom Navigation Logic ---
    
    body = ft.Container(expand=True)

    def set_page_content(index):
        if index == 0: body.content = view_tracker()
        elif index == 1: body.content = view_ranking()
        elif index == 2: body.content = view_cos() # New empty COS view
        elif index == 3: body.content = view_profile()
        elif index == 4: body.content = view_history() # Hidden history view
        page.update()

    def create_nav_item(icon_name, label, index, current_index, image_src=None):
        # Don't highlight if current_index is outside nav range (e.g. 4)
        is_active = (index == current_index)
        color = ACCENT_COLOR if is_active else "#888888"
        
        # Icon or Image content
        if image_src:
            # Increased size for bigger bar
            icon_content = ft.Image(src=image_src, width=55, height=55)
        else:
            icon_content = ft.Icon(icon_name, color=color, size=45)

        return ft.Container(
            content=ft.Column(
                [
                    icon_content,
                    # Label removed as requested to maximize icon size
                ],
                alignment=ft.MainAxisAlignment.CENTER,
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=0
            ),
            on_click=lambda e: on_nav_tap(index),
            expand=True,
            padding=5,
            ink=True
        )

    def render_nav_bar(current_index):
        return ft.Container(
            bgcolor=CARD_COLOR,
            height=95,  # Increased height
            padding=ft.Padding.only(bottom=15, top=10), # Adjusted padding
            border_radius=ft.BorderRadius.only(top_left=20, top_right=20),
            content=ft.Row(
                controls=[
                    create_nav_item("touch_app", "KKpenco", 0, current_index, image_src="opt-1.png"),
                    create_nav_item("leaderboard", "Ranking", 1, current_index, image_src="opt-2.png"),
                    create_nav_item("groups", "COS", 2, current_index),
                    create_nav_item("person", "Perfil", 3, current_index, image_src="opt-4.png"),
                ],
                alignment=ft.MainAxisAlignment.SPACE_AROUND,
                vertical_alignment=ft.CrossAxisAlignment.CENTER
            )
        )

    # --- Navigation Logic ---

    nav_bar_container = ft.Container() 

    def on_nav_tap(index):
        set_page_content(index)
        nav_bar_container.content = render_nav_bar(index)
        nav_bar_container.update()

    def show_main_app():
        page.clean()
        
        # Initial Setup for Main App
        nav_bar_container.content = render_nav_bar(0)
        set_page_content(0)
        
        page.add(
            ft.Column(
                controls=[
                    body,              # Takes all free space
                    nav_bar_container  # Stays at bottom
                ],
                expand=True,
                spacing=0
            )
        )
        page.update()

    # Initial Entry Point
    # Initial Entry Point
    import logging
    try:
        logging.warning("DEBUG: Checking session...")
        saved = await get_session(page)
        if saved:
            logging.warning(f"DEBUG: Found saved session: {saved}")
            current_user["id"] = saved.get("id")
            current_user["username"] = saved.get("username")
        else:
            logging.warning("DEBUG: No saved session found.")

    except Exception as e:
        logging.error(f"Error reading storage: {e}")

    logging.warning(f"DEBUG: Checking current_user: {current_user}")
    if current_user["id"] is None:
        try:
            logging.warning("DEBUG: Showing view_login")
            page.add(view_login())
            logging.warning("DEBUG: view_login added")
        except Exception as e:
            logging.error(f"CRITICAL ERROR adding view_login: {e}")
            page.add(ft.Text(f"CRITICAL ERROR: {e}"))
    else:
        # Initial layout or redirect
        show_main_app()

if __name__ == "__main__":
    print("ROOT: Calling ft.app")
    try:
        import logging
        logging.basicConfig(level=logging.DEBUG)
        print("ROOT: Calling ft.app (DESKTOP RESTORED)")
        ft.app(target=main, view=ft.AppView.FLET_APP, assets_dir="assets")
        print("ROOT: ft.app exited")
    except Exception as e:
        print(f"ROOT: ft.app failed: {e}")
