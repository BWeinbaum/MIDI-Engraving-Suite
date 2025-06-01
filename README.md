# 🎼 MIDI Engraving Suite for Finale v27  

A collection of modular plug-ins designed to streamline **notation workflows** for **contemporary commercial media composers**. This suite reduces tedious tasks, optimizing processes that traditionally take **minutes or hours**, allowing composers to focus on **creativity** rather than manual engraving.

## ✨ Features
- **Combine Articulation Staves** - Recognize individual instruments as combinations of several VST plug-ins for individual articulations. Automatically determine notation style based on the instrument and articulation or based on the program's pre-existing knowledge of the VST plug-in.
- **Superimpose Template** - Rather than copying MIDI data into a template, this tool allows users to superimpose template information into an existing score.
- **Create Tempo Markings** - Automatically recognizes tempo changes and formats them according to contemporary commercial scoring syntax.
- **Label Instrument Numbers** - Formatting tool for professional-looking instrument numbering. Numbers appear left of their staff.
- **Collaboration-Friendly** – Built with **orchestrators** and existing **plug-in companies** in mind, enabling integration and teamwork.  

## 📂 File Structure  
- **Drivers** - These small files are recognized by RGP Lua and displayed in the Finale Plug-in Menu. Most reference modular Lua instructions in the Lib directory.
- **/Lib** - All of the non-driver Lua files appear in this directory.
- **/Lib/Data** - Used to store XML data.

## 🚀 Installation  
1. Download and install [Finale v27](https://www.finalemusic.com/).
2. Download [RGP Lua](https://robertgpatterson.com/-fininfo/-rgplua/rgplua.html#:~:text=RGP%20Lua%20is%20an%20environment%20to%20run%20scripts,which%20unfortunately%20has%20not%20been%20updated%20since%202017.) and place it into the Finale plug-ins folder.
3. Download the plug-in suite and link the base directory (containing the drivers and Lib directory) to Finale using the RGP Lua plug-in.
4. Restart Finale to interact with plug-ins from the program.

## 🛠️ Future Enhancements  
- **Handle Key Switches** - Automatically switch notation styles based on recognized or user-defined key switches.
- **Read and Save Existing Templates** - Apply the ability to superimpose a template using your own. You will also be able to choose from several templates recommended by experienced industry orchestrators.
- **Notation Shortcuts** - Constantly collaborating with existing instrument libraries to create built-in macros that speed up the process of notating specific instrument articulations.

## 🤝 Contributing
This project is currently private and closed-source.
- Select collaborators are welcome to submit issues, requests, or potential improvements via **GitHub Issues**.
- Fork the repository and make a **pull request** with contributions.  

## 📜 License

© Brendan Weinbaum 2025. All rights reserved.

This software and its contents are **copyrighted material** owned by **Brendan Weinbaum**.  
Unauthorized reproduction, modification, distribution, or use of this software without **explicit permission** is prohibited.  

For licensing inquiries, collaboration requests, or special permissions, please contact **brendan@composerscollaborative.com**.
