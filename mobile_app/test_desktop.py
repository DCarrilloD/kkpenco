import flet as ft
import logging

def main(page: ft.Page):
    print("TEST: Entering main")
    page.add(ft.Text("Hola Desktop World"))
    print("TEST: Text added")

if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    try:
        print("TEST: Calling ft.app")
        ft.app(target=main)
    except Exception as e:
        print(f"TEST: Error: {e}")
