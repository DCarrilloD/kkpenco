import toga
from toga.style import Pack
from toga.style.pack import COLUMN, ROW, CENTER, LEFT, RIGHT, BOLD
from shared.models import Consistency, KKEvent
from kkcos.api import APIClient
from datetime import datetime

# --- Modern Dark Theme Palette ---
# Inspired by modern iOS/Android dark modes
BG_ROOT = "#000000"         # True black for OLED
BG_SURFACE = "#1C1C1E"      # Dark Gray for cards
ACCENT_PRIMARY = "#FF9F0A"  # Warm Orange/Gold (Energetic & relates to topic without being literal brown)
ACCENT_SECONDARY = "#32D74B" # Success Green
TEXT_MAIN = "#FFFFFF"
TEXT_SUBLE = "#8E8E93"
TEXT_PLACEHOLDER = "#636366"
SEPARATOR_COLOR = "#38383A"

class KKCoS(toga.App):
    def __init__(self):
        super().__init__(formal_name="KKCoS", app_id="com.example.kkcos")

    def startup(self):
        self.api = APIClient()
        
        # --- Constants for Styles ---
        self.CARD_STYLE = Pack(
            direction=COLUMN, 
            background_color=BG_SURFACE, 
            padding=16, 
            margin_bottom=16
        )
        
        self.LABEL_TITLE_STYLE = Pack(
            color=TEXT_MAIN, 
            font_size=22, 
            font_weight=BOLD, 
            padding_bottom=8, 
            background_color=BG_ROOT
        )
        
        self.LABEL_SUBTITLE_STYLE = Pack(
            color=TEXT_SUBLE, 
            font_size=13, 
            padding_bottom=12,
            background_color=BG_SURFACE
        )

        # Container de Pestañas
        self.main_container = toga.OptionContainer(
            content=[
                toga.OptionItem("Tracker", self.build_tracker_tab()),
                toga.OptionItem("Statistics", self.build_statistics_tab())
            ]
        )

        self.main_window = toga.MainWindow(title=self.formal_name)
        self.main_window.content = self.main_container
        self.main_window.show()

    def build_tracker_tab(self):
        """Construye la pestaña principal de registro con estilo moderno."""
        
        # Root Container
        main_box = toga.Box(style=Pack(direction=COLUMN, padding=20, background_color=BG_ROOT, flex=1))

        # Title
        header = toga.Label("New Entry", style=self.LABEL_TITLE_STYLE)
        main_box.add(header)

        # 1. Action Card (The Big Button)
        # Using a Box to simulate a card container for the button
        action_card = toga.Box(style=Pack(background_color=BG_SURFACE, padding=20, margin_bottom=24, alignment=CENTER))
        
        self.btn_poop = toga.Button(
            'LOG NOW',
            on_press=self.quick_poop,
            style=Pack(
                padding=15, 
                font_size=18, 
                font_weight=BOLD, 
                background_color=ACCENT_PRIMARY, 
                color="black",
                width=250 # Fixed width for pill-like appearance simulation
            )
        )
        action_card.add(self.btn_poop)
        main_box.add(action_card)

        # 2. Details Form
        form_label = toga.Label("Details", style=Pack(color=TEXT_MAIN, font_size=18, font_weight=BOLD, padding_bottom=10, background_color=BG_ROOT))
        main_box.add(form_label)

        form_box = toga.Box(style=self.CARD_STYLE)

        # Consistency Row
        row_cons = toga.Box(style=Pack(direction=ROW, padding_bottom=15, alignment=CENTER, background_color=BG_SURFACE))
        lbl_cons = toga.Label("Consistency", style=Pack(color=TEXT_MAIN, font_size=15, width=100, background_color=BG_SURFACE))
        self.consistency_selection = toga.Selection(
            items=[c.value for c in Consistency],
            style=Pack(flex=1)
        )
        row_cons.add(lbl_cons)
        row_cons.add(self.consistency_selection)
        form_box.add(row_cons)

        # Notes Row
        row_notes = toga.Box(style=Pack(direction=ROW, padding_bottom=15, alignment=CENTER, background_color=BG_SURFACE))
        lbl_notes = toga.Label("Notes", style=Pack(color=TEXT_MAIN, font_size=15, width=100, background_color=BG_SURFACE))
        self.notes_input = toga.TextInput(
            placeholder="Optional...", 
            style=Pack(flex=1, background_color="#2C2C2E", color=TEXT_MAIN) 
            # Note: TextInput coloring support varies by platform in Toga
        )
        row_notes.add(lbl_notes)
        row_notes.add(self.notes_input)
        form_box.add(row_notes)

        # Save Button
        btn_save = toga.Button(
            "Save Details",
            on_press=self.detailed_poop,
            style=Pack(padding_top=10, background_color="#3A3A3C", color=ACCENT_PRIMARY, font_weight=BOLD)
        )
        form_box.add(btn_save)
        
        main_box.add(form_box)

        # Status Footer
        self.status_label = toga.Label(
            "Ready", 
            style=Pack(padding_top=20, color=TEXT_SUBLE, background_color=BG_ROOT, text_align=CENTER, font_size=12)
        )
        main_box.add(self.status_label)

        return main_box

    def build_statistics_tab(self):
        stats_box = toga.Box(style=Pack(direction=COLUMN, padding=20, background_color=BG_ROOT, flex=1))

        # Header
        header_row = toga.Box(style=Pack(direction=ROW, padding_bottom=20, alignment=CENTER, background_color=BG_ROOT))
        title = toga.Label("Statistics", style=self.LABEL_TITLE_STYLE)
        title.style.margin_bottom = 0 # Override
        title.style.flex = 1
        icon = toga.Label("📊", style=Pack(font_size=24, background_color=BG_ROOT))
        header_row.add(title)
        header_row.add(icon)
        stats_box.add(header_row)

        # 1. Weekly Overview Card
        card_overview = toga.Box(style=self.CARD_STYLE)
        card_overview.add(toga.Label("Weekly Output", style=self.LABEL_SUBTITLE_STYLE))
        
        # Bars Container
        bars_box = toga.Box(style=Pack(direction=ROW, height=100, alignment=CENTER, background_color=BG_SURFACE))
        # Simulated data
        data = [2, 4, 1, 5, 3, 0, 2] # Poops per day
        max_val = 5
        days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        for count, day in zip(data, days):
            # Column per day
            day_col = toga.Box(style=Pack(direction=COLUMN, flex=1, alignment=CENTER, padding=2, background_color=BG_SURFACE))
            
            # Bar height calculation (simple flex ratio or fixed height math)
            bar_height = max(10, (count / max_val) * 60)
            
            # Invisible spacer top
            day_col.add(toga.Box(style=Pack(flex=1, background_color=BG_SURFACE))) 
            
            # The Bar
            color = ACCENT_PRIMARY if count > 0 else "#2C2C2E"
            bar = toga.Box(style=Pack(width=12, height=bar_height, background_color=color))
            day_col.add(bar)
            
            # Day Label
            lbl = toga.Label(day, style=Pack(color=TEXT_SUBLE, font_size=10, padding_top=8, background_color=BG_SURFACE))
            day_col.add(lbl)
            
            bars_box.add(day_col)
            
        card_overview.add(bars_box)
        
        insight = toga.Label(
            "Healthy frequency this week!", 
            style=Pack(color=ACCENT_SECONDARY, font_size=12, padding_top=10, font_weight=BOLD, background_color=BG_SURFACE)
        )
        card_overview.add(insight)
        stats_box.add(card_overview)

        # 2. Stats Grid
        # Row 1
        row1 = toga.Box(style=Pack(direction=ROW, margin_bottom=16, background_color=BG_ROOT))
        row1.add(self.build_metric_card("Total Logged", "14", "💩", flex=1, margin_right=16))
        row1.add(self.build_metric_card("Streak", "5 Days", "🔥", flex=1))
        stats_box.add(row1)

        # Row 2
        row2 = toga.Box(style=Pack(direction=ROW, background_color=BG_ROOT))
        row2.add(self.build_metric_card("Avg Time", "4m 20s", "⏱️", flex=1, margin_right=16))
        row2.add(self.build_metric_card("Rating", "Jurásica", "🦖", flex=1))
        stats_box.add(row2)

        return stats_box

    def build_metric_card(self, title, value, icon, flex=1, margin_right=0):
        """Creates a styled metric card."""
        card = toga.Box(style=Pack(
            direction=COLUMN, 
            background_color=BG_SURFACE, 
            padding=12, 
            flex=flex,
            margin_right=margin_right
        ))
        
        header = toga.Box(style=Pack(direction=ROW, margin_bottom=8, background_color=BG_SURFACE))
        lbl_icon = toga.Label(icon, style=Pack(font_size=16, margin_right=5, background_color=BG_SURFACE))
        lbl_title = toga.Label(title, style=Pack(color=TEXT_SUBLE, font_size=12, background_color=BG_SURFACE))
        header.add(lbl_icon)
        header.add(lbl_title)
        
        lbl_val = toga.Label(value, style=Pack(color=TEXT_MAIN, font_size=20, font_weight=BOLD, background_color=BG_SURFACE))
        
        card.add(header)
        card.add(lbl_val)
        return card

    def quick_poop(self, widget):
        self.send_event(Consistency.NORMAL, notes="Quick Log")

    def detailed_poop(self, widget):
        consistency_str = self.consistency_selection.value
        consistency_enum = next((c for c in Consistency if c.value == consistency_str), Consistency.NORMAL)
        notes = self.notes_input.value
        self.send_event(consistency_enum, notes=notes)

    def send_event(self, consistency: Consistency, notes: str = None):
        event = KKEvent(
            user_id=1,
            consistency=consistency,
            notes=notes,
            timestamp=datetime.utcnow()
        )
        
        self.status_label.text = "Syncing..."
        success = self.api.create_event(event)
        
        if success:
            self.status_label.text = "Saved successfully."
            if notes != "Quick Log":
                self.notes_input.value = ""
        else:
            self.status_label.text = "Failed to connect to server."

def main():
    return KKCoS()
